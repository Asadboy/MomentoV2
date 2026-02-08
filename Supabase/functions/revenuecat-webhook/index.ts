// supabase/functions/revenuecat-webhook/index.ts
//
// RevenueCat webhook handler for Momento premium purchases.
//
// Receives webhook events from RevenueCat and marks events as premium
// in Supabase. This provides server-side verification of purchases
// as a complement to the client-side flow.
//
// Setup:
//   1. In RevenueCat dashboard → Integrations → Webhooks
//   2. Set URL to: https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
//   3. Set Authorization header to match REVENUECAT_WEBHOOK_SECRET env var

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Verify webhook authorization
  const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (webhookSecret) {
    const authHeader = req.headers.get("Authorization");
    if (authHeader !== `Bearer ${webhookSecret}`) {
      console.error("[webhook] Invalid authorization header");
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  try {
    const body = await req.json();
    const event = body.event;

    if (!event) {
      return new Response(JSON.stringify({ error: "No event in payload" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[webhook] Received event: ${event.type}`);

    // We only care about successful purchases
    // RevenueCat sends: INITIAL_PURCHASE, RENEWAL, NON_RENEWING_PURCHASE
    const purchaseEvents = [
      "INITIAL_PURCHASE",
      "NON_RENEWING_PURCHASE",
    ];

    if (!purchaseEvents.includes(event.type)) {
      console.log(`[webhook] Ignoring event type: ${event.type}`);
      return new Response(JSON.stringify({ status: "ignored" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Extract event ID from subscriber attributes
    // The iOS app should set a subscriber attribute "event_id" before purchase
    const subscriberAttributes = event.subscriber_attributes || {};
    const eventIdAttr = subscriberAttributes["event_id"];
    const eventId = eventIdAttr?.value;

    if (!eventId) {
      console.warn("[webhook] No event_id in subscriber attributes, skipping DB update");
      // Still return 200 so RevenueCat doesn't retry
      return new Response(JSON.stringify({ status: "ok", note: "no event_id attribute" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const transactionId = event.transaction_id || event.store_transaction_id || "webhook";

    // Initialize Supabase
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    // Mark event as premium
    const { error: updateError } = await supabase
      .from("events")
      .update({
        is_premium: true,
        premium_purchased_at: new Date().toISOString(),
        premium_transaction_id: transactionId,
        expires_at: null, // Premium events never expire
      })
      .eq("id", eventId);

    if (updateError) {
      console.error(`[webhook] Failed to mark event ${eventId} as premium:`, updateError);
      return new Response(
        JSON.stringify({ error: `DB update failed: ${updateError.message}` }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`[webhook] Marked event ${eventId} as premium (tx: ${transactionId})`);

    return new Response(
      JSON.stringify({ status: "ok", event_id: eventId, transaction_id: transactionId }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("[webhook] Error processing webhook:", error);

    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
