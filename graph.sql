-- task 1 - done
-- task 2 - done
-- task 3 - done
-- task 4 - done
-- task 5 - done
-- task 6 - done
-- task 7
-- task 8 - done
-- task 9
-- task 10 - done

CREATE SCHEMA IF NOT EXISTS hw1;

DROP TABLE IF EXISTS hw1.users cascade;
CREATE TABLE hw1.users(
    user_id BIGSERIAL NOT NULL,
    name TEXT,
    surname TEXT,
    chief_id INTEGER,

    PRIMARY KEY (user_id)
);

-- task1

CREATE OR REPLACE FUNCTION hw1.add_user(
  name  TEXT,
  surname   TEXT,
  chief_id INTEGER
) RETURNS void
AS $$
BEGIN
    INSERT INTO hw1.users(name, surname, chief_id)
    VALUES(name, surname, COALESCE(chief_id, -1));
END;
$$ LANGUAGE plpgsql;

-- samples
select hw1.add_user('Kvinsi', 'Promes', -1);
select hw1.add_user('Sasha', 'Sobolev', 1);
select hw1.add_user('Anton', 'Zinkovskiy', 2);
select hw1.add_user('Pavel', 'Maslov', 2);
select hw1.add_user('George', 'Dgikia', 2);
select hw1.add_user('Sasha', 'Selihov', 2);
select hw1.add_user('Sasha', 'Maximenko', 1);
select hw1.add_user('Nikita', 'Prutcev', 7);
select hw1.add_user('Ruslan', 'Litvinov', 7);
select hw1.add_user('Leon', 'Klassen', 9);
select hw1.add_user('Nikolay', 'Rasskazov', 9);

-- task 2
CREATE OR REPLACE FUNCTION hw1.move_user_to_another_department(
  user_bd_id INTEGER,
  new_chief_id INTEGER
) RETURNS void
AS $$
BEGIN
    UPDATE hw1.users
        SET chief_id = new_chief_id
    WHERE user_id = user_bd_id;
END;
$$ LANGUAGE plpgsql;

select hw1.move_user_to_another_department(2, 3);

-- task 3

DROP FUNCTION IF EXISTS hw1.get_users;
CREATE OR REPLACE FUNCTION hw1.get_users(
    department_id INTEGER
) RETURNS TABLE(chief_name TEXT, users TEXT[]) AS $$
    SELECT chief.name || ' ' || chief.surname AS chief_name,
           (SELECT array_agg(u.name || ' ' || u.surname)
            FROM hw1.users u
                     INNER JOIN hw1.users AS chief ON chief.user_id = u.chief_id
            WHERE u.chief_id = department_id
            )
    FROM hw1.users chief
    where chief.user_id = department_id
    GROUP BY chief_name

    UNION ALL

    SELECT ' ' AS chief_name, array_agg(u.name || ' ' || u.surname) FROM hw1.users u
    where department_id = -1  AND u.chief_id = department_id
    GROUP BY chief_name;

$$ LANGUAGE SQL;

SELECT hw1.get_users(9);

-- task 4

DROP VIEW IF EXISTS departments;
CREATE OR REPLACE VIEW departments (user_id, chief_id, chief_name, users_count) AS
    SELECT ch.user_id, ch.chief_id, ch.name || ' ' || ch.surname, count(ch.user_id) FROM hw1.users ch
    INNER JOIN hw1.users u ON u.chief_id = ch.user_id
    GROUP BY ch.user_id;

select * from departments;


select user_id, name || ' ' || surname  FROM hw1.users
WHERE user_id NOT IN (SELECT user_id FROM departments);

-- task 5

DROP VIEW IF EXISTS employee_hierarchy;
CREATE OR REPLACE RECURSIVE VIEW employee_hierarchy (user_id, full_name, path, user_rank) AS
  SELECT user_id, name || ' ' || surname AS full_name, 'Big Boss' AS path, 0 AS user_rank
  FROM hw1.users
  WHERE chief_id = -1

  UNION ALL

SELECT
    e.user_id,
    e.name || ' ' || e.surname AS full_name,
    e.name || ' ' || e.surname || '->' || employee_hierarchy.path AS path,
    employee_hierarchy.user_rank + 1
  FROM hw1.users e, employee_hierarchy
  WHERE e.chief_id = employee_hierarchy.user_id;

SELECT
	full_name, path, user_rank
FROM
	employee_hierarchy;

-- task 6

DROP FUNCTION IF EXISTS hw1.get_size_department;
CREATE OR REPLACE FUNCTION hw1.get_size_department(
    department_id BIGINT
) RETURNS TABLE(size INTEGER) AS $$
    WITH RECURSIVE t(user_iid) AS (
      SELECT department_id AS user_iid

      UNION ALL

      SELECT user_iid FROM (
        WITH last AS (
            SELECT * FROM t
        )
        SELECT user_id AS user_iid FROM hw1.users
        INNER JOIN last ON last.user_iid = hw1.users.chief_id
      ) AS user_iid
    )
    SELECT count(user_iid) FROM t;

$$ LANGUAGE SQL;

select hw1.get_size_department(9);

-- task 8

SELECT full_name, user_rank, path
FROM employee_hierarchy
where user_id = 3;

-- task 10

-- description:
-- make ranks of users equals
-- after that goes up until find ancestor

DROP FUNCTION IF EXISTS hw1.get_path;
CREATE OR REPLACE FUNCTION hw1.get_path(
    first_user INTEGER,
    second_user INTEGER
) RETURNS TEXT AS $$
DECLARE
    first_user_rank int := (SELECT user_rank FROM employee_hierarchy where user_id = first_user);
    second_user_rank int := (SELECT user_rank FROM employee_hierarchy where user_id = second_user);
    first_str text := '';
    second_str text:= '';
BEGIN
	WHILE first_user_rank < second_user_rank LOOP
	    second_user_rank:= second_user_rank - 1;
	    IF (second_str = '') THEN
	        second_str := (SELECT name || surname FROM hw1.users WHERE user_id = second_user);
        ELSE
            second_str := (SELECT name || surname FROM hw1.users WHERE user_id = second_user) || '->' || second_str;
        end if;
	    second_user := (SELECT chief_id FROM hw1.users WHERE user_id = second_user);
	END LOOP;
	WHILE second_user_rank < first_user_rank LOOP
	    first_user_rank:= first_user_rank - 1;
	    IF (first_str = '') THEN
            first_str:= (SELECT name || surname FROM hw1.users WHERE user_id = first_user);
	    ELSE
	        first_str:= first_str || '->' || (SELECT name || surname FROM hw1.users WHERE user_id = first_user);
	    end if;
	    first_user := (SELECT chief_id FROM hw1.users WHERE user_id = first_user);
	END LOOP;
	WHILE first_user <> second_user LOOP
	    IF (first_str = '') THEN
	        first_str:= (SELECT name || surname FROM hw1.users WHERE user_id = first_user);
	    ELSE
    	    first_str:= first_str || '->' || (SELECT name || surname FROM hw1.users WHERE user_id = first_user);
        end if;

	    first_user := (SELECT chief_id FROM hw1.users WHERE user_id = first_user);
	    IF (second_str = '') THEN
	        second_str := (SELECT name || surname FROM hw1.users WHERE user_id = second_user);
        ELSE
            second_str:= (SELECT name || surname FROM hw1.users WHERE user_id = second_user) || '->' || second_str;
        end if;
	    second_user := (SELECT chief_id FROM hw1.users WHERE user_id = second_user);
    end loop;

	IF (first_str = '') THEN
	    first_str := (SELECT name || surname FROM hw1.users WHERE user_id = first_user);
	ELSE
        first_str := first_str || '->' || (SELECT name || surname FROM hw1.users WHERE user_id = first_user);
    end if;

	IF (first_str = '') THEN
        RETURN second_str;
    ELSEIF (second_str = '') THEN
        RETURN first_str;
	ELSE
        RETURN first_str || '->' || second_str;
    END IF;
END;
$$ LANGUAGE plpgsql;

select hw1.get_path(9, 2);

