// =============================================================================
// FILE: supabase/functions/dispatch-alert/index.ts
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") ?? "";
const ONESIGNAL_REST_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface AlertPayload {
  alertType: "iot_breach" | "new_appointment" | "tuesday_approval" | "pabuklat_ready" | "pabuklat_request" | "general";
  title: string;
  message: string;
  targetRoles?: string[];
  targetUserIds?: string[];
  additionalData?: Record<string, unknown>;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body: AlertPayload = await req.json();
    const { alertType, title, message, targetRoles, targetUserIds, additionalData } = body;

    if (!title || !message) {
      return new Response(
        JSON.stringify({ error: "Missing required 'title' or 'message' parameters." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_KEY) {
      console.error("[dispatch-alert] Missing ONESIGNAL_APP_ID or ONESIGNAL_REST_API_KEY.");
      return new Response(
        JSON.stringify({ error: "OneSignal API credentials are not configured on Supabase." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase admin client to log into public.notifications
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Record alert in public.notifications so in-app bell tray updates
    try {
      const notificationRows: Record<string, unknown>[] = [];
      const referenceId = (additionalData?.node_id ?? additionalData?.reference_id ?? null) as string | null;

      if (targetUserIds && targetUserIds.length > 0) {
        for (const uid of targetUserIds) {
          notificationRows.push({
            user_id: uid,
            title,
            message,
            notification_type: alertType,
            reference_id: referenceId,
          });
        }
      } else if (targetRoles && targetRoles.length > 0) {
        for (const role of targetRoles) {
          notificationRows.push({
            target_role: role.toLowerCase(),
            title,
            message,
            notification_type: alertType,
            reference_id: referenceId,
          });
        }
      } else if (alertType === "iot_breach") {
        // Default to all operational staff roles
        for (const role of ["secretary", "parishpriest", "admin"]) {
          notificationRows.push({
            target_role: role,
            title,
            message,
            notification_type: alertType,
            reference_id: referenceId,
          });
        }
      }

      if (notificationRows.length > 0) {
        const { error: dbError } = await supabase.from("notifications").insert(notificationRows);
        if (dbError) {
          console.error("[dispatch-alert] Database notification insert note:", dbError);
        } else {
          console.log(`[dispatch-alert] Successfully logged ${notificationRows.length} in-app notification row(s).`);
        }
      }
    } catch (dbErr) {
      console.error("[dispatch-alert] Non-blocking DB log error:", dbErr);
    }

    // 2. Base OneSignal Push Payload
    const oneSignalBody: Record<string, unknown> = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: title },
      contents: { en: message },
      priority: 10,
      android_accent_color: "FF164E87", // Marian Blue Accent
      data: {
        type: alertType,
        timestamp: new Date().toISOString(),
        ...(additionalData ?? {}),
      },
    };

    // 3. Resolve Target Devices
    // Direct Target: Specific Supabase user_id(s) / External ID
    if (targetUserIds && targetUserIds.length > 0) {
      oneSignalBody["include_aliases"] = {
        external_id: targetUserIds,
      };
      oneSignalBody["target_channel"] = "push";
    }
    // Specific Roles Requested (e.g., ["secretary", "parishpriest"])
    else if (targetRoles && targetRoles.length > 0) {
      const filters: Record<string, unknown>[] = [];
      targetRoles.forEach((role, idx) => {
        if (idx > 0) filters.push({ operator: "OR" });
        filters.push({
          field: "tag",
          key: "role",
          relation: "=",
          value: role.toLowerCase(),
        });
      });
      oneSignalBody["filters"] = filters;
    }
    // IoT Breach Default: Only staff roles (Excludes regular parishioners 'user')
    else if (alertType === "iot_breach") {
      const staffRoles = ["secretary", "parishpriest", "admin", "encoder"];
      const filters: Record<string, unknown>[] = [];
      staffRoles.forEach((role, idx) => {
        if (idx > 0) filters.push({ operator: "OR" });
        filters.push({
          field: "tag",
          key: "role",
          relation: "=",
          value: role,
        });
      });
      oneSignalBody["filters"] = filters;
    }
    // Fallback broadcast
    else {
      oneSignalBody["included_segments"] = ["Total Subscriptions", "Subscribed Users"];
    }

    console.log(`[dispatch-alert] Payload to OneSignal:`, JSON.stringify(oneSignalBody));

    const response = await fetch("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${ONESIGNAL_REST_KEY}`,
      },
      body: JSON.stringify(oneSignalBody),
    });

    const responseText = await response.text();
    console.log(`[dispatch-alert] OneSignal API response (${response.status}):`, responseText);

    return new Response(responseText, {
      status: response.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[dispatch-alert] Error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});