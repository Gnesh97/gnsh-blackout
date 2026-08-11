-- gnsh-blackout — Phase 14/21 Persistence (spec §45)
--
-- The two original tables match spec §45's "minimum tablolar" list.
-- Phase 21 adds the component-overrides table below without changing them.
-- infrastructure_substations / infrastructure_maintenance are explicitly
-- out of scope ("ileride") — substation state is always derived from its
-- transformers at runtime, never stored (server/substation_manager.lua).
--
-- Column names are snake_case; shared/types.lua's Types.NewTransformer()
-- / Types.NewIncident() field names were chosen in Phase 1 specifically
-- to map onto these 1:1 (camelCase <-> snake_case only), so
-- server/persistence.lua's mapping is mechanical, not a redesign.

CREATE TABLE IF NOT EXISTS `infrastructure_transformers` (
    `transformer_id` VARCHAR(64) NOT NULL,
    `substation_id`  VARCHAR(64)     NULL,
    `state`          VARCHAR(32) NOT NULL DEFAULT 'ONLINE',
    `condition`      VARCHAR(32) NOT NULL DEFAULT 'HEALTHY',
    `damage`         INT         NOT NULL DEFAULT 0,
    `last_failure`   INT             NULL,
    `last_repair`    INT             NULL,
    `updated_at`     INT         NOT NULL DEFAULT 0,
    PRIMARY KEY (`transformer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `infrastructure_incidents` (
    `incident_id`    VARCHAR(32) NOT NULL,
    `grid_id`        VARCHAR(64) NOT NULL,
    -- JSON-encoded array (Types.NewIncident().districts is a Lua list) —
    -- see json.encode/json.decode usage in server/persistence.lua.
    `districts`      TEXT            NULL,
    `substation_id`  VARCHAR(64)     NULL,
    `transformer_id` VARCHAR(64)     NULL,
    `cause`          VARCHAR(32) NOT NULL DEFAULT 'UNKNOWN',
    -- Stored as text: existing code passes both numeric severities
    -- (sabotage damage amounts, e.g. "60") and string labels (the
    -- Types.NewIncident() default "MINOR") into this same field — not a
    -- new inconsistency introduced by persistence, just preserved as-is.
    `severity`       VARCHAR(16) NOT NULL DEFAULT 'MINOR',
    `status`         VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    -- started_by / repaired_by store the player's server `source` at the
    -- time of the event — an ephemeral per-session id, not a persistent
    -- player identifier. Matches how Phase 11/12 already used this field
    -- in memory; a real player identifier (citizenid/license) is a
    -- separate future improvement, not part of this phase's scope.
    `started_by`     VARCHAR(64)     NULL,
    `started_at`     INT             NULL,
    `repaired_by`    VARCHAR(64)     NULL,
    `completed_at`   INT             NULL,
    -- JSON-encoded free-form table (repair progress, etc. — spec §38).
    `metadata`       TEXT            NULL,
    PRIMARY KEY (`incident_id`),
    INDEX `idx_infrastructure_incidents_status` (`status`),
    INDEX `idx_infrastructure_incidents_grid` (`grid_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Phase 21 parent infrastructure failure overrides. Child transformer
-- records remain in infrastructure_transformers; this table stores only
-- explicit grid/substation/feeder operational blocks.
CREATE TABLE IF NOT EXISTS `infrastructure_component_overrides` (
    `component_type` VARCHAR(16) NOT NULL,
    `component_id`   VARCHAR(64) NOT NULL,
    `state`          VARCHAR(16) NOT NULL DEFAULT 'OFFLINE',
    `reason`         VARCHAR(128) NULL,
    `updated_by`     VARCHAR(64) NULL,
    `updated_at`     INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`component_type`, `component_id`),
    INDEX `idx_infrastructure_overrides_state` (`state`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
