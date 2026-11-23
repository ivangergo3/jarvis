-- Use the private instance password for administration and the Auth service.
\getenv jarvis_password POSTGRES_PASSWORD
\getenv auth_password JARVIS_AUTH_PASSWORD
alter role postgres with password :'jarvis_password';
alter role supabase_auth_admin with password :'auth_password';
