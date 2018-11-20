CREATE OR REPLACE FUNCTION _array_to_sorted_string( name[], text )
RETURNS text AS $$
    SELECT array_to_string(ARRAY(
        SELECT $1[i]
          FROM generate_series(1, array_upper($1, 1)) s(i)
         ORDER BY $1[i]
    ), $2);
$$ LANGUAGE SQL immutable;

-- policies_are( schema, table, policies[], description )
CREATE OR REPLACE FUNCTION policies_are( NAME, NAME, NAME[], TEXT )
RETURNS TEXT AS $$
    SELECT _are(
        'policies',
        ARRAY(
            SELECT p.polname
              FROM pg_catalog.pg_policy p
              JOIN pg_catalog.pg_class c     ON c.oid = p.polrelid
              JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = $1
               AND c.relname = $2
            EXCEPT
            SELECT $3[i]
              FROM generate_series(1, array_upper($3, 1)) s(i)
        ),
        ARRAY(
            SELECT $3[i]
              FROM generate_series(1, array_upper($3, 1)) s(i)
            EXCEPT
            SELECT p.polname
              FROM pg_catalog.pg_policy p
              JOIN pg_catalog.pg_class c     ON c.oid = p.polrelid
              JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = $1
               AND c.relname = $2
        ),
        $4
    );
$$ LANGUAGE SQL;

-- policies_are( schema, table, policies[] )
CREATE OR REPLACE FUNCTION policies_are( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT policies_are( $1, $2, $3, 'Table ' || quote_ident($1) || '.' || quote_ident($2) || ' should have the correct policies' );
$$ LANGUAGE SQL;

-- policies_are( table, policies[], description )
CREATE OR REPLACE FUNCTION policies_are( NAME, NAME[], TEXT )
RETURNS TEXT AS $$
    SELECT _are(
        'policies',
        ARRAY(
            SELECT p.polname
              FROM pg_catalog.pg_policy p
              JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
              JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
             WHERE c.relname = $1
               AND n.nspname NOT IN ('pg_catalog', 'information_schema')
            EXCEPT
            SELECT $2[i]
              FROM generate_series(1, array_upper($2, 1)) s(i)
        ),
        ARRAY(
            SELECT $2[i]
              FROM generate_series(1, array_upper($2, 1)) s(i)
            EXCEPT
            SELECT p.polname
              FROM pg_catalog.pg_policy p
              JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
              JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
               AND n.nspname NOT IN ('pg_catalog', 'information_schema')
        ),
        $3
    );
$$ LANGUAGE SQL;

-- policies_are( table, policies[] )
CREATE OR REPLACE FUNCTION policies_are( NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT policies_are( $1, $2, 'Table ' || quote_ident($1) || ' should have the correct policies' );
$$ LANGUAGE SQL;

-- policy_roles_are( schema, table, policy, roles[], description )
CREATE OR REPLACE FUNCTION policy_roles_are( NAME, NAME, NAME, NAME[], TEXT )
RETURNS TEXT AS $$
    SELECT _are(
        'policy roles',
        ARRAY(
            SELECT pr.rolname
              FROM pg_catalog.pg_policy AS pp
              JOIN pg_catalog.pg_roles AS pr ON pr.oid = ANY (pp.polroles)
              JOIN pg_catalog.pg_class AS pc ON pc.oid = pp.polrelid
              JOIN pg_catalog.pg_namespace AS pn ON pn.oid = pc.relnamespace
             WHERE pn.nspname = $1
               AND pc.relname = $2
               AND pp.polname = $3
            EXCEPT
            SELECT $4[i]
              FROM generate_series(1, array_upper($4, 1)) s(i)
        ),
        ARRAY(
            SELECT $4[i]
              FROM generate_series(1, array_upper($4, 1)) s(i)
            EXCEPT
            SELECT pr.rolname
              FROM pg_catalog.pg_policy AS pp
              JOIN pg_catalog.pg_roles AS pr ON pr.oid = ANY (pp.polroles)
              JOIN pg_catalog.pg_class AS pc ON pc.oid = pp.polrelid
              JOIN pg_catalog.pg_namespace AS pn ON pn.oid = pc.relnamespace
             WHERE pn.nspname = $1
               AND pc.relname = $2
               AND pp.polname = $3
        ),
        $5
    );
$$ LANGUAGE SQL;

-- policy_roles_are( schema, table, policy, roles[] )
CREATE OR REPLACE FUNCTION policy_roles_are( NAME, NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT policy_roles_are( $1, $2, $3, $4, 'Policy ' || quote_ident($3) || ' for table ' || quote_ident($1) || '.' || quote_ident($2) || ' should have the correct roles' );
$$ LANGUAGE SQL;

-- policy_roles_are( table, policy, roles[], description )
CREATE OR REPLACE FUNCTION policy_roles_are( NAME, NAME, NAME[], TEXT )
RETURNS TEXT AS $$
    SELECT _are(
        'policy roles',
        ARRAY(
            SELECT pr.rolname
              FROM pg_catalog.pg_policy AS pp
              JOIN pg_catalog.pg_roles AS pr ON pr.oid = ANY (pp.polroles)
              JOIN pg_catalog.pg_class AS pc ON pc.oid = pp.polrelid
              JOIN pg_catalog.pg_namespace AS pn ON pn.oid = pc.relnamespace
             WHERE pc.relname = $1
               AND pp.polname = $2
               AND pn.nspname NOT IN ('pg_catalog', 'information_schema')
            EXCEPT
            SELECT $3[i]
              FROM generate_series(1, array_upper($3, 1)) s(i)
        ),
        ARRAY(
            SELECT $3[i]
              FROM generate_series(1, array_upper($3, 1)) s(i)
            EXCEPT
            SELECT pr.rolname
              FROM pg_catalog.pg_policy AS pp
              JOIN pg_catalog.pg_roles AS pr ON pr.oid = ANY (pp.polroles)
              JOIN pg_catalog.pg_class AS pc ON pc.oid = pp.polrelid
              JOIN pg_catalog.pg_namespace AS pn ON pn.oid = pc.relnamespace
             WHERE pc.relname = $1
               AND pp.polname = $2
               AND pn.nspname NOT IN ('pg_catalog', 'information_schema')
        ),
        $4
    );
$$ LANGUAGE SQL;

-- policy_roles_are( table, policy, roles[] )
CREATE OR REPLACE FUNCTION policy_roles_are( NAME, NAME, NAME[] )
RETURNS TEXT AS $$
    SELECT policy_roles_are( $1, $2, $3, 'Policy ' || quote_ident($2) || ' for table ' || quote_ident($1) || ' should have the correct roles' );
$$ LANGUAGE SQL;

-- policy_cmd_is( schema, table, policy, command, description )
CREATE OR REPLACE FUNCTION policy_cmd_is( NAME, NAME, NAME, text, text )
RETURNS TEXT AS $$
DECLARE
    cmd text;
BEGIN
    SELECT
      CASE pp.polcmd WHEN 'r' THEN 'SELECT'
                     WHEN 'a' THEN 'INSERT'
                     WHEN 'w' THEN 'UPDATE'
                     WHEN 'd' THEN 'DELETE'
                     ELSE 'ALL'
       END
      FROM pg_catalog.pg_policy AS pp
      JOIN pg_catalog.pg_class AS pc ON pc.oid = pp.polrelid
      JOIN pg_catalog.pg_namespace AS pn ON pn.oid = pc.relnamespace
     WHERE pn.nspname = $1
       AND pc.relname = $2
       AND pp.polname = $3
      INTO cmd;

    RETURN is( cmd, upper($4), $5 );
END;
$$ LANGUAGE plpgsql;

-- policy_cmd_is( schema, table, policy, command )
CREATE OR REPLACE FUNCTION policy_cmd_is( NAME, NAME, NAME, text )
RETURNS TEXT AS $$
    SELECT policy_cmd_is(
        $1, $2, $3, $4,
        'Policy ' || quote_ident($3)
        || ' for table ' || quote_ident($1) || '.' || quote_ident($2)
        || ' should apply to ' || upper($4) || ' command'
    );
$$ LANGUAGE sql;

-- policy_cmd_is( table, policy, command, description )
CREATE OR REPLACE FUNCTION policy_cmd_is( NAME, NAME, text, text )
RETURNS TEXT AS $$
DECLARE
    cmd text;
BEGIN
    SELECT
      CASE pp.polcmd WHEN 'r' THEN 'SELECT'
                     WHEN 'a' THEN 'INSERT'
                     WHEN 'w' THEN 'UPDATE'
                     WHEN 'd' THEN 'DELETE'
                     ELSE 'ALL'
       END
      FROM pg_catalog.pg_policy AS pp
      JOIN pg_catalog.pg_class AS pc ON pc.oid = pp.polrelid
      JOIN pg_catalog.pg_namespace AS pn ON pn.oid = pc.relnamespace
     WHERE pc.relname = $1
       AND pp.polname = $2
       AND pn.nspname NOT IN ('pg_catalog', 'information_schema')
      INTO cmd;

    RETURN is( cmd, upper($3), $4 );
END;
$$ LANGUAGE plpgsql;

-- policy_cmd_is( table, policy, command )
CREATE OR REPLACE FUNCTION policy_cmd_is( NAME, NAME, text )
RETURNS TEXT AS $$
    SELECT policy_cmd_is(
        $1, $2, $3,
        'Policy ' || quote_ident($2)
        || ' for table ' || quote_ident($1)
        || ' should apply to ' || upper($3) || ' command'
    );
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION _funkargs ( NAME[] )
RETURNS TEXT AS $$
BEGIN
    RETURN array_to_string($1::regtype[], ',');
EXCEPTION WHEN undefined_object THEN
    RETURN array_to_string($1, ',');
END;
$$ LANGUAGE PLPGSQL STABLE;

CREATE OR REPLACE FUNCTION _got_func ( NAME, NAME, NAME[] )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT TRUE
          FROM tap_funky
         WHERE schema = $1
           AND name   = $2
           AND args = _funkargs($3)
    );
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION _got_func ( NAME, NAME[] )
RETURNS BOOLEAN AS $$
    SELECT EXISTS(
        SELECT TRUE
          FROM tap_funky
         WHERE name = $1
           AND args = _funkargs($2)
           AND is_visible
    );
$$ LANGUAGE SQL;