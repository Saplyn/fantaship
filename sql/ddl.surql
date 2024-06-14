-- ns/db: main/main
BEGIN TRANSACTION;
DEFINE NAMESPACE main;
USE NS main;
DEFINE DATABASE main;
USE DB main;
COMMIT TRANSACTION;



-- fn: check if record exists
DEFINE FUNCTION fn::record::exists($rec: record) {
    RETURN !!$rec.id;
};
-- fn: check if an array of record all exists
DEFINE FUNCTION fn::record::all_exists($arr: array<record>) {
    LET $res = true;
    FOR $rec IN $arr {
        IF fn::record::exists($rec) THEN
            $res = $res AND true
        ELSE
            $res = false
        END
    };
    RETURN $res;
};



-- tb: dbg (debug/log)
DEFINE TABLE dbg SCHEMAFULL TYPE NORMAL
    PERMISSIONS FULL;
DEFINE FIELD src ON dbg TYPE string;
DEFINE FIELD msg ON dbg TYPE option<string>;
DEFINE FIELD obj ON dbg FLEXIBLE TYPE option<object>;



-- tb: user/developer
DEFINE TABLE developer SCHEMAFULL TYPE NORMAL
    PERMISSIONS
        FOR select, update, delete WHERE id = $auth.id
        FOR create NONE;
DEFINE FIELD name ON developer TYPE string;
DEFINE FIELD pswd ON developer TYPE string /* ASSERT string::len() > 8 */;
-- rule: user/developer
DEFINE INDEX name ON developer FIELDS name UNIQUE; -- name is unique
-- auth: user/developer
DEFINE SCOPE developer SESSION 1d
    SIGNIN {
        CREATE ONLY dbg CONTENT { src: "developer/sc:signin", obj: $value };
        RETURN SELECT * OMIT pswd FROM developer WHERE name = $name AND crypto::argon2::compare(pswd, $pswd);
    }
    SIGNUP {
        CREATE ONLY dbg CONTENT { src: "developer/sc:signup", obj: $value };
        RETURN CREATE ONLY developer CONTENT {
            id: $name,
            name: $name,
            pswd: crypto::argon2::generate($pswd)
        };
    };



-- tb: package
DEFINE TABLE package SCHEMAFULL TYPE NORMAL
    PERMISSIONS
        FOR delete WHERE publisher = $auth.id -- publisher can alter
        FOR create NONE  -- must publish through `portal`
        FOR select, update WHERE publisher = $auth.id; -- self can see
DEFINE FIELD name      ON package TYPE string;
DEFINE FIELD publisher ON package TYPE record<developer>            ASSERT fn::record::exists($value);
DEFINE FIELD source    ON package TYPE option<record<github | git>> ASSERT type::is::none($value) OR fn::record::exists($value);
DEFINE FIELD extract   ON package TYPE option<string>               ASSERT type::is::none($value) OR $value IN ["tar", "zip", "rar"];
DEFINE FIELD install   ON package TYPE option<record<executable>>   ASSERT type::is::none($value) OR fn::record::exists($value);
-- rule: package
DEFINE INDEX name ON package FIELDS name UNIQUE; -- name is unique
-- event: cascade delete
DEFINE EVENT cascade_delete ON package WHEN $event = "DELETE" THEN {
    CREATE ONLY dbg CONTENT { src: "package/ev:cascade_delete", obj: $after };
    -- remove `source`
    IF not(type::is::none($before.source)) THEN {
        LET $src = meta::tb($before.source);
        IF      $src = "github" THEN DELETE github WHERE id = $before.source
        ELSE IF $src = "git"    THEN DELETE git    WHERE id = $before.source
        END;
    } END;
    -- remove `install`
    IF not(type::is::none($before.install)) THEN {
        LET $ins = meta::tb($before.install);
        IF $ins = "executable" THEN DELETE executable WHERE id = $before.install
        END;
    } END;
};
        

-- tb: available_package (view)
DEFINE TABLE available_package SCHEMAFULL TYPE NORMAL
    AS SELECT id AS pid, * FROM package WHERE not(type::is::none(source) OR type::is::none(install))
    PERMISSIONS
        FOR select FULL
        FOR update, create, delete NONE;
DEFINE FIELD name      ON available_package TYPE string;
DEFINE FIELD pid       ON available_package TYPE record<package>;
DEFINE FIELD publisher ON available_package TYPE record<developer>;
DEFINE FIELD source    ON available_package TYPE record<github | git>;
DEFINE FIELD extract   ON available_package TYPE option<string>;
DEFINE FIELD install   ON available_package TYPE record<executable>;
DEFINE EVENT drop_subs ON available_package WHEN $event = "DELETE" THEN {
    DELETE subscribe WHERE out NOT IN (
        SELECT VALUE id FROM $after
    );
};



-- tb: source/github
DEFINE TABLE github SCHEMAFULL TYPE NORMAL
    PERMISSIONS
        FOR update WHERE package.publisher = $auth.id AND package.source = id            -- can alter content
        FOR create WHERE package.publisher = $auth.id AND type::is::none(package.source) -- can fill empty
        FOR delete WHERE package.publisher = $auth.id
        FOR select WHERE package.publisher = $auth.id OR (
            array::any(array::matches(
                (SELECT pid FROM available_package),
                { pid: package }
            ))
        );
DEFINE FIELD package ON github TYPE record<package> ASSERT fn::record::exists($value);
DEFINE FIELD owner   ON github TYPE string;
DEFINE FIELD repo    ON github TYPE string;
DEFINE FIELD v_regex ON github TYPE string;
-- ev: source/github (link package to source)
DEFINE EVENT link_pkg ON github WHEN $event = "CREATE" THEN {
    CREATE dbg CONTENT { src: "github/ev:link_pkg", obj: $after };
    UPDATE package SET source = $after.id WHERE id = $after.package;
};
DEFINE EVENT unlink_pkg ON github WHEN $event = "DELETE" THEN {
    CREATE dbg CONTENT { src: "github/ev:unlink_pkg", obj: $after };
    UPDATE package SET source = NONE WHERE id = $before.package;
};



-- tb: source/git
DEFINE TABLE git SCHEMAFULL
    PERMISSIONS
        FOR update WHERE package.publisher = $auth.id AND package.source = id            -- can alter content
        FOR create WHERE package.publisher = $auth.id AND type::is::none(package.source) -- can fill empty
        FOR delete WHERE package.publisher = $auth.id
        FOR select WHERE package.publisher = $auth.id OR (
            array::any(array::matches(
                (SELECT pid FROM available_package),
                { pid: package }
            ))
        );
DEFINE FIELD package ON git TYPE record<package> ASSERT fn::record::exists($value);
DEFINE FIELD origin  ON git TYPE string;
-- ev: source/github (link package to source)
DEFINE EVENT link_pkg ON git WHEN $event = "CREATE" THEN {
    CREATE dbg CONTENT { src: "git/ev:link_pkg", obj: $after };
    UPDATE package SET source = $after.id WHERE id = $after.package;
};
DEFINE EVENT unlink_pkg ON git WHEN $event = "DELETE" THEN {
    CREATE dbg CONTENT { src: "git/ev:unlink_pkg", obj: $after };
    UPDATE package SET source = NONE WHERE id = $before.package;
};



-- tb: install/executable
DEFINE TABLE executable SCHEMAFULL TYPE NORMAL
    PERMISSIONS
        FOR update WHERE package.publisher = $auth.id AND package.install = id             -- can alter content
        FOR create WHERE package.publisher = $auth.id AND type::is::none(package.install) -- can fill empty
        FOR delete WHERE package.publisher = $auth.id
        FOR select WHERE package.publisher = $auth.id OR (
            array::any(array::matches(
                (SELECT pid FROM available_package),
                { pid: package }
            ))
        );
DEFINE FIELD package ON executable TYPE record<package> ASSERT fn::record::exists($value);
DEFINE FIELD target  ON executable TYPE string;
DEFINE FIELD rename  ON executable TYPE option<string>;
-- ev: install/executable (link package install)
DEFINE EVENT link_pkg ON executable WHEN $event = "CREATE" THEN {
    CREATE dbg CONTENT { src: "executable/ev:link_pkg", obj: $after };
    UPDATE package SET install = $after.id WHERE id = $after.package;
};
DEFINE EVENT unlink_pkg ON executable WHEN $event = "DELETE" THEN {
    CREATE dbg CONTENT { src: "executable/ev:unlink_pkg", obj: $after };
    UPDATE package SET install = NONE WHERE id = $before.package;
};
DEFINE EVENT pure_dbg ON executable WHEN $event = "SELECT" THEN {
    CREATE dbg CONTENT { src: "executable/ev:pure_dbg $input", obj: $input };
    CREATE dbg CONTENT { src: "executable/ev:pure_dbg $parent", obj: $parent };
    CREATE dbg CONTENT { src: "executable/ev:pure_dbg $this", obj: $this };
    CREATE dbg CONTENT { src: "executable/ev:pure_dbg $value", obj: $value };
};



-- tb: portal_publish (package publish entry)
DEFINE TABLE portal_publish SCHEMAFULL TYPE NORMAL
    PERMISSIONS
        FOR create WHERE (
            SELECT count() == 1 FROM developer WHERE id == $auth.id
        )
        FOR select, delete, update NONE;
DEFINE FIELD name ON portal_publish TYPE string;
-- ev: portal_publish (publish package & remove entry)
DEFINE EVENT publish_package ON portal_publish WHEN $event = "CREATE" THEN {
    CREATE dbg CONTENT { src: "portal_publish/ev:publish_package", obj: $after };
    CREATE ONLY package CONTENT {
        name:      $after.name,
        publisher: $auth.id,
        source:    NONE,
        extract:   NONE,
        install:   NONE,
    };
    DELETE portal_publish WHERE id = $after.id;
};

DEFINE TABLE guest SCHEMAFULL TYPE NORMAL
    PERMISSIONS
        FOR select WHERE id = $auth.id
        FOR create, update, delete NONE;
DEFINE FIELD name ON guest TYPE string;
-- auth: user/developer
DEFINE SCOPE guest SESSION 1d
    SIGNIN {
        CREATE ONLY dbg CONTENT { src: "guest/sc:signin", obj: $value };
        RETURN SELECT * FROM guest WHERE name = $name;
    }
    SIGNUP {
        CREATE ONLY dbg CONTENT { src: "guest/sc:signup", obj: $value };
        RETURN CREATE ONLY guest CONTENT {
            id: $name,
            name: $name,
        };
    };
CREATE ONLY guest CONTENT {
    name: "guest"
};

--------------------------------------------------------------------------------------



-- tb: user/audience
DEFINE TABLE audience SCHEMAFULL TYPE NORMAL
    PERMISSIONS
        FOR select, update, delete WHERE id = $auth.id
        FOR create NONE;
DEFINE FIELD name ON audience TYPE string;
DEFINE FIELD pswd ON audience TYPE string;
-- rule: user/audience
DEFINE INDEX name ON audience FIELDS name UNIQUE; -- name is unique
-- auth: user/audience
DEFINE SCOPE audience SESSION 1d
    SIGNIN {
        CREATE ONLY dbg CONTENT { src: "audience/sc:signin", obj: $value };
        RETURN SELECT * OMIT pswd FROM audience WHERE name = $name AND crypto::argon2::compare(pswd, $pswd);
    }
    SIGNUP {
        CREATE ONLY dbg CONTENT { src: "audience/sc:signup", obj: $value };
        RETURN CREATE ONLY audience CONTENT {
            id: $name,
            name: $name,
            pswd: crypto::argon2::generate($pswd)
        };
    };



-- tb: user->subscribe->package
DEFINE TABLE subscribe SCHEMAFULL
    TYPE RELATION FROM audience TO available_package
    PERMISSIONS
        FOR select, create, delete WHERE ((SELECT count() == 1 FROM audience WHERE id == $auth.id) AND in = $auth.id)
        FOR update NONE;
DEFINE INDEX unique_subscribe ON subscribe FIELDS in, out UNIQUE;

