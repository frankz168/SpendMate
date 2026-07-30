-- ==============================================
-- V13: Migrate User Repository to SP (Functions)
-- ==============================================

-- 1. spendmate_user_getbyusername
CREATE OR REPLACE FUNCTION spendmate_user_getbyusername(p_username VARCHAR)
RETURNS TABLE (
    id INT,
    name VARCHAR,
    phonenumber VARCHAR,
    username VARCHAR,
    PasswordHash VARCHAR,
    createdate TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, 
        u.name, 
        u.phonenumber, 
        u.username, 
        u.password_hash as PasswordHash, 
        u.createdate 
    FROM users u
    WHERE u.username = p_username;
END;
$$ LANGUAGE plpgsql;

-- 2. spendmate_user_getbyid
CREATE OR REPLACE FUNCTION spendmate_user_getbyid(p_id INT)
RETURNS TABLE (
    id INT,
    name VARCHAR,
    phonenumber VARCHAR,
    username VARCHAR,
    PasswordHash VARCHAR,
    createdate TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, 
        u.name, 
        u.phonenumber, 
        u.username, 
        u.password_hash as PasswordHash, 
        u.createdate 
    FROM users u
    WHERE u.id = p_id;
END;
$$ LANGUAGE plpgsql;

-- 3. spendmate_user_getall
CREATE OR REPLACE FUNCTION spendmate_user_getall()
RETURNS TABLE (
    id INT,
    name VARCHAR,
    phonenumber VARCHAR,
    username VARCHAR,
    createdate TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, 
        u.name, 
        u.phonenumber, 
        u.username, 
        u.createdate 
    FROM users u
    ORDER BY u.createdate DESC;
END;
$$ LANGUAGE plpgsql;

-- 4. spendmate_user_insert
CREATE OR REPLACE FUNCTION spendmate_user_insert(
    p_name VARCHAR,
    p_phonenumber VARCHAR,
    p_username VARCHAR,
    p_password_hash VARCHAR
) RETURNS VOID AS $$
BEGIN
    INSERT INTO users (name, phonenumber, username, password_hash)
    VALUES (p_name, p_phonenumber, p_username, p_password_hash);
END;
$$ LANGUAGE plpgsql;

-- 5. spendmate_user_update
CREATE OR REPLACE FUNCTION spendmate_user_update(
    p_id INT,
    p_name VARCHAR,
    p_phonenumber VARCHAR,
    p_username VARCHAR,
    p_password_hash VARCHAR
) RETURNS VOID AS $$
BEGIN
    IF p_password_hash IS NOT NULL AND p_password_hash != '' THEN
        UPDATE users 
        SET name = p_name, 
            phonenumber = p_phonenumber, 
            username = p_username, 
            password_hash = p_password_hash
        WHERE id = p_id;
    ELSE
        UPDATE users 
        SET name = p_name, 
            phonenumber = p_phonenumber, 
            username = p_username
        WHERE id = p_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 6. spendmate_user_delete
CREATE OR REPLACE FUNCTION spendmate_user_delete(p_id INT) 
RETURNS VOID AS $$
BEGIN
    DELETE FROM users WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;
