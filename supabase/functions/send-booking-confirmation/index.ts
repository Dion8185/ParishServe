import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY')
const SENDER_EMAIL = Deno.env.get('SENDER_EMAIL') || 'lucator51plus1@gmail.com'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Canonical document requirements helper per service
function getRequirementsHtml(serviceType: string): string {
  const s = (serviceType || '').toLowerCase()
  let items: string[] = []

  if (s.includes('wedding') || s.includes('nuptial')) {
    items = [
      'PSA Authenticated Birth Certificate (Groom & Bride)',
      'PSA Certificate of No Marriage (CENOMAR) (Valid within 6 months)',
      'Newly Issued Baptismal Certificate with "FOR MARRIAGE PURPOSES" annotation',
      'Newly Issued Confirmation Certificate with "FOR MARRIAGE PURPOSES" annotation',
      'Pre-Cana Seminar Certificate of Attendance',
      'Canonical Interview with Parish Priest / Parochial Vicar',
      'Marriage License (LCR) or PSA Marriage Contract (if civilly married)',
      'Parish Marriage Banns (Tawag) clearance from respective home parishes',
      'List of Principal Sponsors (Ninong & Ninang) and 2x2 ID photos',
    ]
  } else if (s.includes('baptism')) {
    items = [
      'PSA Birth Certificate / Certified True Copy of Live Birth of the child',
      "Parents' PSA Catholic Marriage Contract (or Certificate of No Marriage/COLB Acknowledgement under Canon 877 if unmarried)",
      'Baptismal & Confirmation Certificates of Catholic Godparents (Ninong & Ninang)',
      'Pre-Baptismal Seminar Attendance Certificate (Parents & Sponsors)',
      'Photocopy of Valid Government ID of Parents',
    ]
  } else if (s.includes('funeral')) {
    items = [
      'Certified True Copy of Death Certificate',
      'Burial / Transfer / Cremation Permit (from LCR or Municipal Health Office)',
      'Photocopy of Valid Government ID of the requesting next of kin',
    ]
  } else if (s.includes('anointing') || s.includes('sick call') || s.includes('blessing')) {
    items = [
      'Exact residential address and landmark directions for the pastoral home visit',
      'Photocopy of Valid Government ID of the requesting family member',
    ]
  } else if (s.includes('thanksgiving') || s.includes('mass intention')) {
    items = [
      'Printed or digital copy of booking confirmation reference',
      'Mass stipend / offering settlement receipt at the parish secretariat desk',
    ]
  } else {
    items = [
      'Valid Government-Issued Identification Document of the requester',
      'Supporting pastoral or canonical documents requested by the Parish Office',
    ]
  }

  return items.map(item => `<li style="margin-bottom: 6px;">${item}</li>`).join('')
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload = await req.json()

    const {
      appointment_id,
      requester_name,
      email,
      service_type,
      requested_date,
      requested_time,
      end_time,
      venue,
      officiant_name,
      appointment_remarks,
    } = payload

    if (!email) {
      return new Response(JSON.stringify({ error: 'No recipient email provided' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (!BREVO_API_KEY) {
      return new Response(JSON.stringify({ error: 'BREVO_API_KEY secret is not configured in Supabase' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const requirementsList = getRequirementsHtml(service_type)

    const htmlEmail = `
      <!DOCTYPE html>
      <html>
      <body style="font-family: Arial, sans-serif; color: #1E293B; background-color: #F8FAFC; padding: 20px; margin: 0;">
        <div style="max-width: 600px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; border: 1px solid #CBD5E1; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05);">

          <!-- Header Banner -->
          <div style="background-color: #164E87; padding: 26px; text-align: center; color: #FFFFFF;">
            <h2 style="margin: 0; font-size: 20px; letter-spacing: 0.5px;">ST. JOHN PAUL II PARISH</h2>
            <p style="margin: 4px 0 0; font-size: 13px; color: #D49B18; font-weight: bold;">Diocese of San Pablo • Labuin, Sta. Cruz, Laguna</p>
          </div>

          <!-- Body Content -->
          <div style="padding: 26px;">
            <div style="background-color: #EDF7F2; border-left: 4px solid #2D6A4F; padding: 12px 16px; border-radius: 6px; margin-bottom: 20px;">
              <strong style="color: #2D6A4F; font-size: 15px;">✓ Appointment Request Confirmed & Approved</strong>
            </div>

            <p style="font-size: 14px; margin-top: 0;">Dear <strong>${requester_name || 'Parishioner'}</strong>,</p>
            <p style="font-size: 14px; line-height: 1.5; color: #334155;">
              Peace be with you! We are pleased to inform you that your appointment request for <strong>${service_type || 'Parish Service'}</strong> has been reviewed and officially <strong>approved</strong> by the Parish Office.
            </p>

            <!-- Schedule Box -->
            <div style="background-color: #EDF4FB; border: 1px solid #CBD5E1; border-radius: 10px; padding: 16px; margin: 20px 0;">
              <table style="width: 100%; font-size: 13px; color: #1E293B; border-collapse: collapse;">
                <tr><td style="padding: 5px 0; color: #64748B; width: 140px;">Booking Reference:</td><td style="font-weight: bold; color: #164E87;">${appointment_id}</td></tr>
                <tr><td style="padding: 5px 0; color: #64748B;">Service:</td><td style="font-weight: bold;">${service_type}</td></tr>
                <tr><td style="padding: 5px 0; color: #64748B;">Confirmed Date:</td><td style="font-weight: bold;">${requested_date}</td></tr>
                <tr><td style="padding: 5px 0; color: #64748B;">Time Window:</td><td style="font-weight: bold;">${requested_time} – ${end_time}</td></tr>
                <tr><td style="padding: 5px 0; color: #64748B;">Parish Venue:</td><td style="font-weight: bold;">${venue || 'Main Church Altar'}</td></tr>
                <tr><td style="padding: 5px 0; color: #64748B;">Presiding Clergy:</td><td style="font-weight: bold;">${officiant_name || 'Rev. Fr. Joseph Santos'}</td></tr>
                ${appointment_remarks ? `<tr><td style="padding: 5px 0; color: #64748B;">Remarks:</td><td style="font-style: italic; color: #475569;">${appointment_remarks}</td></tr>` : ''}
              </table>
            </div>

            <!-- Canonical Requirements Checklist -->
            <h4 style="margin: 20px 0 8px; color: #164E87; font-size: 14px;">Physical Documents to Submit at the Parish:</h4>
            <ul style="font-size: 13px; color: #475569; line-height: 1.5; padding-left: 20px; margin-top: 0;">
              ${requirementsList}
            </ul>

            <!-- Parish Office Schedule -->
            <div style="background-color: #F1F5F9; padding: 12px 16px; border-radius: 8px; font-size: 12px; color: #475569; line-height: 1.4; border: 1px solid #E2E8F0; margin-top: 20px;">
              <strong>Parish Secretariat Office Hours for Submissions:</strong><br>
              Tuesday to Sunday: 8:00 AM – 12:00 PM | 1:30 PM – 5:00 PM<br>
              <em>Closed on Mondays (Clergy Rest Day & Office Sanitation)</em><br>
              <strong>Location:</strong> Parish Secretariat, St. John Paul II Parish, Brgy. Labuin, Sta. Cruz, Laguna
            </div>

            <p style="margin-top: 28px; font-family: serif; font-style: italic; color: #D49B18; font-weight: bold; font-size: 13px; text-align: center; letter-spacing: 2px;">
              TOTUS TUUS
            </p>
          </div>
        </div>
      </body>
      </html>
    `

    // Dispatch via Brevo REST API (Signed with verified DKIM & SPF)
    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'accept': 'application/json',
        'api-key': BREVO_API_KEY,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        sender: {
          name: 'St. John Paul II Parish',
          email: SENDER_EMAIL,
        },
        to: [
          {
            email: email,
            name: requester_name || 'Parishioner',
          },
        ],
        subject: `[CONFIRMED] Parish Appointment: ${service_type} (${appointment_id})`,
        htmlContent: htmlEmail,
      }),
    })

    const result = await response.json()

    return new Response(JSON.stringify(result), {
      status: response.status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})