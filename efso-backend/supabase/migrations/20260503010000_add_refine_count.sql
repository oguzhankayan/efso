-- Efso v2 usage counters: separate free refinement quota and Istanbul day boundary.

ALTER TABLE public.usage_daily
    ADD COLUMN IF NOT EXISTS refine_count INT NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.fn_increment_usage(p_user_id UUID, p_cost_usd DECIMAL DEFAULT 0)
RETURNS INT AS $$
DECLARE
    new_count INT;
    today_tr DATE := (NOW() AT TIME ZONE 'Europe/Istanbul')::DATE;
BEGIN
    INSERT INTO public.usage_daily (user_id, date, generation_count, refine_count, llm_cost_usd)
    VALUES (p_user_id, today_tr, 1, 0, p_cost_usd)
    ON CONFLICT (user_id, date)
    DO UPDATE SET
        generation_count = usage_daily.generation_count + 1,
        llm_cost_usd = usage_daily.llm_cost_usd + EXCLUDED.llm_cost_usd
    RETURNING generation_count INTO new_count;
    RETURN new_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.fn_increment_refine(p_user_id UUID, p_cost_usd DECIMAL DEFAULT 0)
RETURNS INT AS $$
DECLARE
    new_count INT;
    today_tr DATE := (NOW() AT TIME ZONE 'Europe/Istanbul')::DATE;
BEGIN
    INSERT INTO public.usage_daily (user_id, date, generation_count, refine_count, llm_cost_usd)
    VALUES (p_user_id, today_tr, 0, 1, p_cost_usd)
    ON CONFLICT (user_id, date)
    DO UPDATE SET
        refine_count = usage_daily.refine_count + 1,
        llm_cost_usd = usage_daily.llm_cost_usd + EXCLUDED.llm_cost_usd
    RETURNING refine_count INTO new_count;
    RETURN new_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
