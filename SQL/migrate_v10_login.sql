-- 1. Add columns to users
ALTER TABLE users ADD COLUMN IF NOT EXISTS username VARCHAR(50) UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);

-- 2. Update Franky with default credentials
UPDATE users 
SET username = 'franky', 
    password_hash = '$2a$11$NT/573MY5bX1GAFwNBJQOe5rKaGrf/BZuSZfmhTu0od7YiCOgVrfm' 
WHERE id = 1;
