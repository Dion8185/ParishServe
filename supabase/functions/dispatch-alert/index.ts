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
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface AlertPayload {
  alertType: "iot_breach" | "new_appointment" | "tuesday_approval" | "pabuklat_ready" | "pabuklat_request" | "general";
  title: string;
  message: string;
  targetRoles?: string[];
  targetUserIds?: string[];
  additionalData?: Record<string, unknown>;
  // Root-level telemetry keys sent by the ESP32
  node_id?: string;
  nodeId?: string;
  temperature?: number | string;
  humidity?: number | string;
}

serve(async (req) => {
  // 1. Handle CORS preflight requests
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

    // Initialize Supabase admin client with service_role key to bypass RLS
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Resolve hardware node ID / reference ID (handles nested and top-level fields)
    const referenceId = (
      additionalData?.node_id ??
      additionalData?.reference_id ??
      body.node_id ??
      body.nodeId ??
      "ESP32-NODE-01"
    ) as string;

    // Resolve temperature and humidity
    const rawTemp = additionalData?.temperature ?? body.temperature ?? "31.8";
    const rawHum = additionalData?.humidity ?? body.humidity ?? "63.0";

    // =========================================================================
    // 1. RECORD IN public.notifications (In-App Bell Tray)
    // =========================================================================
    try {
      const notificationRows: Record<string, unknown>[] = [];

      // FIX FOR 3 DUPLICATE NOTIFICATIONS:
      // For IoT Breaches, insert EXACTLY ONE row with 'all_staff'.
      // InAppNotificationService queries target_role.eq.all_staff,
      // so all staff (secretary, priest, admin) will see it without duplicate cards!
      if (alertType === "iot_breach") {
        notificationRows.push({
          target_role: "all_staff",
          title,
          message,
          notification_type: alertType,
          reference_id: referenceId,
          is_read: false,
          is_cleared: false,
        });
      } else if (targetUserIds && targetUserIds.length > 0) {
        // Direct notifications targeted to specific user UUIDs
        for (const uid of targetUserIds) {
          notificationRows.push({
            user_id: uid,
            title,
            message,
            notification_type: alertType,
            reference_id: referenceId,
            is_read: false,
            is_cleared: false,
          });
        }
      } else if (targetRoles && targetRoles.length > 0) {
        // Specific role targeting
        for (const role of targetRoles) {
          notificationRows.push({
            target_role: role.toLowerCase().trim(),
            title,
            message,
            notification_type: alertType,
            reference_id: referenceId,
            is_read: false,
            is_cleared: false,
          });
        }
      } else {
        // General broadcast fallback
        notificationRows.push({
          target_role: "all_staff",
          title,
          message,
          notification_type: alertType,
          reference_id: referenceId,
          is_read: false,
          is_cleared: false,
        });
      }

      if (notificationRows.length > 0) {
        const { error: dbError } = await supabase.from("notifications").insert(notificationRows);
        if (dbError) {
          console.error("[dispatch-alert] Database notification insert note:", dbError);
        } else {
          console.log(`[dispatch-alert] Logged ${notificationRows.length} in-app notification row(s).`);
        }
      }
    } catch (dbErr) {
      console.error("[dispatch-alert] Non-blocking DB log error:", dbErr);
    }

    // =========================================================================
    // 2. LOG TO public.sensor_telemetry_logs (For 24-Hour Sparkline Chart)
    // =========================================================================
    if (alertType === "iot_breach") {
      try {
        const tempNum = parseFloat(String(rawTemp)) || 24.0;
        const humNum = parseFloat(String(rawHum)) || 50.0;
        const telemetryId = `TEL-${Date.now()}`;

        await supabase.from("sensor_telemetry_logs").insert({
          telemetry_id: telemetryId,
          node_id: referenceId,
          temperature: tempNum,
          humidity: humNum,
          is_warning: true,
          alert_type: "humidity_breach",
          recorded_at: new Date().toISOString(),
        });
        console.log(`[dispatch-alert] Telemetry log recorded for node: ${referenceId}`);
      } catch (logErr) {
        console.error("[dispatch-alert] Telemetry log error:", logErr);
      }
    }

    // =========================================================================
    // 3. BASE ONESIGNAL PUSH PAYLOAD (Lock Screen Banner)
    // =========================================================================
    const oneSignalBody: Record<string, unknown> = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: title },
      contents: { en: message },
      priority: 10,
      android_accent_color: "FF164E87", // Marian Blue Accent
      data: {
        type: alertType,
        alertType: alertType,
        notification_type: alertType,
        node_id: referenceId,
        reference_id: referenceId,
        temperature: rawTemp,
        humidity: rawHum,
        timestamp: new Date().toISOString(),
        ...(additionalData ?? {}),
      },
    };

    // Resolve Target Devices for OneSignal Push
    if (targetUserIds && targetUserIds.length > 0) {
      oneSignalBody["include_aliases"] = { external_id: targetUserIds };
      oneSignalBody["target_channel"] = "push";
    } else if (alertType === "iot_breach") {
      // Send lock screen push to all operational staff devices
      const staffRoles = ["secretary", "parish_secretary", "parishpriest", "admin", "encoder"];
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
    } else if (targetRoles && targetRoles.length > 0) {
      const filters: Record<string, unknown>[] = [];
      targetRoles.forEach((role, idx) => {
        if (idx > 0) filters.push({ operator: "OR" });
        filters.push({
          field: "tag",
          key: "role",
          relation: "=",
          value: role.toLowerCase().trim(),
        });
      });
      oneSignalBody["filters"] = filters;
    } else {
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