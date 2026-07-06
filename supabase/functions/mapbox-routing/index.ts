// Splitway Edge Function: mapbox-routing
//
// Proxies requests to the Mapbox Map Matching API so the client never
// exposes the secret Mapbox token. Accepts an array of GPS coordinates
// and returns the matched route geometry + duration/distance metadata.
//
// POST /mapbox-routing
// Body: { coordinates: [[lng, lat], ...], profile?: "driving" | "cycling" | "walking" }
// Returns: Mapbox Map Matching API response (GeoJSON)
//
// Required env vars (set in Supabase Dashboard → Edge Functions → Secrets):
//   MAPBOX_SERVER_TOKEN — a Mapbox secret token with Map Matching scope.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const MAPBOX_BASE = "https://api.mapbox.com/matching/v5/mapbox";

// Per-user rate limit for the (paid) Mapbox Map Matching proxy.
const RATE_LIMIT_MAX = 60; // requests…
const RATE_LIMIT_WINDOW_SECONDS = 60; // …per minute, per user.

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

interface RequestBody {
  coordinates: [number, number][];
  profile?: "driving" | "cycling" | "walking";
  radiuses?: number[];
  timestamps?: number[];
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Require an Authorization header AND validate the JWT — presence
    //    alone is not enough (audit SEC-1). Reject anything that isn't a
    //    real, current Supabase user token.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header" }, 401);
    }

    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
    );
    const { data: { user }, error: authError } = await anonClient.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );
    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    // 2. Per-user rate limit, enforced server-side via a SECURITY DEFINER
    //    RPC so a single user can't run up the Mapbox bill.
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );
    // The RPC returns a single row { allowed, retry_after_seconds }. We use
    // .single() so the client returns the object directly instead of a list.
    const { data: quota, error: quotaError } = await adminClient
      .rpc("consume_mapbox_quota", {
        p_user_id: user.id,
        p_max: RATE_LIMIT_MAX,
        p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
      })
      .single();
    if (quotaError) {
      return json({ error: "Rate-limit check failed" }, 500);
    }
    const allowed = (quota as { allowed?: boolean } | null)?.allowed;
    if (allowed === false) {
      const retryAfter =
        (quota as { retry_after_seconds?: number } | null)?.retry_after_seconds
          ?? RATE_LIMIT_WINDOW_SECONDS;
      return new Response(
        JSON.stringify({ error: "Rate limit exceeded. Try again shortly." }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            // RFC 7231: Retry-After is a delta-seconds value; the client
            // (RoutingService._parseRetryAfter) reads this to size its backoff.
            "Retry-After": String(retryAfter),
          },
        },
      );
    }

    const mapboxToken = Deno.env.get("MAPBOX_SERVER_TOKEN");
    if (!mapboxToken) {
      return new Response(
        JSON.stringify({ error: "MAPBOX_SERVER_TOKEN not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = (await req.json()) as RequestBody;
    const { coordinates, profile = "driving", radiuses, timestamps } = body;

    if (!coordinates || coordinates.length < 2) {
      return new Response(
        JSON.stringify({ error: "Need at least 2 coordinates" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (coordinates.length > 100) {
      return new Response(
        JSON.stringify({ error: "Maximum 100 coordinates per request" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build Mapbox Map Matching URL
    const coordString = coordinates
      .map(([lng, lat]) => `${lng},${lat}`)
      .join(";");

    const params = new URLSearchParams({
      access_token: mapboxToken,
      geometries: "geojson",
      overview: "full",
      steps: "false",
      annotations: "duration,distance,speed",
    });

    if (radiuses && radiuses.length === coordinates.length) {
      params.set("radiuses", radiuses.join(";"));
    }

    if (timestamps && timestamps.length === coordinates.length) {
      params.set("timestamps", timestamps.join(";"));
    }

    const mapboxUrl = `${MAPBOX_BASE}/${profile}/${coordString}?${params}`;

    const mapboxRes = await fetch(mapboxUrl);
    const mapboxData = await mapboxRes.json();

    if (!mapboxRes.ok) {
      return new Response(JSON.stringify(mapboxData), {
        status: mapboxRes.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify(mapboxData), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
