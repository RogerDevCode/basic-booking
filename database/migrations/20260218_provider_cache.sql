-- Migration: Add provider_cache table
-- Date: 2026-02-18
-- Purpose: Cache provider data to reduce DB queries

-- Create provider_cache table
CREATE TABLE IF NOT EXISTS public.provider_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES public.providers(id) ON DELETE CASCADE,
    provider_slug TEXT NOT NULL UNIQUE,
    data JSONB NOT NULL,
    cached_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_provider_cache_slug ON public.provider_cache(provider_slug);
CREATE INDEX IF NOT EXISTS idx_provider_cache_expires ON public.provider_cache(expires_at);

-- Add max_retries column to notification_queue if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'notification_queue' 
        AND column_name = 'max_retries'
    ) THEN
        ALTER TABLE public.notification_queue ADD COLUMN max_retries INTEGER DEFAULT 3;
    END IF;
END $$;

-- Add next_retry_at column to notification_queue if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'notification_queue' 
        AND column_name = 'next_retry_at'
    ) THEN
        ALTER TABLE public.notification_queue ADD COLUMN next_retry_at TIMESTAMPTZ;
    END IF;
END $$;

-- Add channel column to notification_queue if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'notification_queue' 
        AND column_name = 'channel'
    ) THEN
        ALTER TABLE public.notification_queue ADD COLUMN channel VARCHAR(50) DEFAULT 'telegram';
    END IF;
END $$;

-- Add recipient column to notification_queue if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'notification_queue' 
        AND column_name = 'recipient'
    ) THEN
        ALTER TABLE public.notification_queue ADD COLUMN recipient TEXT;
    END IF;
END $$;

-- Add payload column to notification_queue if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'notification_queue' 
        AND column_name = 'payload'
    ) THEN
        ALTER TABLE public.notification_queue ADD COLUMN payload JSONB;
    END IF;
END $$;
