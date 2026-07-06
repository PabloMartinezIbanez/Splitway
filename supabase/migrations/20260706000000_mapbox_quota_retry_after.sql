-- Extend consume_mapbox_quota() so the edge function can send a real
-- Retry-After header on 429s instead of making the client guess.
--
-- Change: the RPC now returns a (allowed, retry_after_seconds) row. When
-- allowed = true, retry_after_seconds is 0. When allowed = false, it is the
-- number of seconds until the current window resets (clamped to
-- p_window_seconds so a clock drift can't return a negative value).
--
-- The previous scalar-boolean signature is dropped in the same statement so
-- there is no ambiguity for the edge function.

drop function if exists public.consume_mapbox_quota(uuid, integer, integer);

create or replace function public.consume_mapbox_quota(
  p_user_id uuid,
  p_max integer,
  p_window_seconds integer
) returns table(allowed boolean, retry_after_seconds integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now          timestamptz := now();
  v_window_start timestamptz;
  v_count        integer;
begin
  insert into public.mapbox_quota (user_id, window_start, count)
  values (p_user_id, v_now, 1)
  on conflict (user_id) do update set
    window_start = case
      when public.mapbox_quota.window_start
           < v_now - make_interval(secs => p_window_seconds)
      then v_now
      else public.mapbox_quota.window_start
    end,
    count = case
      when public.mapbox_quota.window_start
           < v_now - make_interval(secs => p_window_seconds)
      then 1
      else public.mapbox_quota.count + 1
    end
  returning window_start, count into v_window_start, v_count;

  allowed := v_count <= p_max;
  if allowed then
    retry_after_seconds := 0;
  else
    -- Seconds until the current fixed window resets. Clamp to
    -- [1, p_window_seconds] to defend against clock skew.
    retry_after_seconds := greatest(
      1,
      least(
        p_window_seconds,
        ceil(
          extract(
            epoch from (
              v_window_start
              + make_interval(secs => p_window_seconds)
              - v_now
            )
          )
        )::integer
      )
    );
  end if;
  return next;
end;
$$;

revoke execute on function
  public.consume_mapbox_quota(uuid, integer, integer) from public, anon, authenticated;
grant execute on function
  public.consume_mapbox_quota(uuid, integer, integer) to service_role;
