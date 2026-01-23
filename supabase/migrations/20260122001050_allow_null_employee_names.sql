-- Migration: Allow NULL values for first_name and last_name in employees table
-- This is needed because:
-- 1. Invited users may not have names set until they accept the invitation
-- 2. Profiles may have incomplete data that still needs employee records

ALTER TABLE employees ALTER COLUMN first_name DROP NOT NULL;
ALTER TABLE employees ALTER COLUMN last_name DROP NOT NULL;
