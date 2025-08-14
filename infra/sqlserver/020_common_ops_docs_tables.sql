-- COMMON catalogs
CREATE TABLE COMMON.CODE_SET (
  id            UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() CONSTRAINT PK_CODE_SET PRIMARY KEY,
  tenant_id     UNIQUEIDENTIFIER NOT NULL,
  code_set_name NVARCHAR(100)    NOT NULL,
  description   NVARCHAR(500)    NULL,
  is_active     BIT              NOT NULL DEFAULT 1,
  created_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  is_deleted    BIT              NOT NULL DEFAULT 0,
  version       ROWVERSION
);

CREATE TABLE COMMON.CODE_VALUE (
  id            UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() CONSTRAINT PK_CODE_VALUE PRIMARY KEY,
  tenant_id     UNIQUEIDENTIFIER NOT NULL,
  code_set_id   UNIQUEIDENTIFIER NOT NULL,
  code          NVARCHAR(50)     NOT NULL,
  display_value NVARCHAR(200)    NOT NULL,
  sort_order    INT              NOT NULL DEFAULT 0,
  is_active     BIT              NOT NULL DEFAULT 1,
  created_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  is_deleted    BIT              NOT NULL DEFAULT 0,
  version       ROWVERSION,
  CONSTRAINT FK_CODE_VALUE_SET FOREIGN KEY (code_set_id) REFERENCES COMMON.CODE_SET(id)
);

CREATE TABLE COMMON.COUNTRY (
  id            UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() CONSTRAINT PK_COUNTRY PRIMARY KEY,
  iso2_code     NVARCHAR(2)      NOT NULL,
  iso3_code     NVARCHAR(3)      NOT NULL,
  country_name  NVARCHAR(200)    NOT NULL,
  numeric_code  NVARCHAR(3)      NULL,
  is_active     BIT              NOT NULL DEFAULT 1,
  created_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  is_deleted    BIT              NOT NULL DEFAULT 0,
  version       ROWVERSION
);

CREATE TABLE COMMON.CURRENCY (
  id             UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() CONSTRAINT PK_CURRENCY PRIMARY KEY,
  currency_code  CHAR(3)          NOT NULL,
  currency_name  NVARCHAR(100)    NOT NULL,
  symbol         NVARCHAR(10)     NULL,
  decimal_places INT              NOT NULL DEFAULT 2,
  is_active      BIT              NOT NULL DEFAULT 1,
  created_at     DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at     DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  is_deleted     BIT              NOT NULL DEFAULT 0,
  version        ROWVERSION
);

CREATE TABLE COMMON.LANGUAGE (
  id            UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() CONSTRAINT PK_LANGUAGE PRIMARY KEY,
  language_code NVARCHAR(10)     NOT NULL,
  language_name NVARCHAR(100)    NOT NULL,
  native_name   NVARCHAR(100)    NULL,
  is_active     BIT              NOT NULL DEFAULT 1,
  created_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  is_deleted    BIT              NOT NULL DEFAULT 0,
  version       ROWVERSION
);

-- OPS
CREATE TABLE OPS.AUDIT_LOG (
  id           UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() CONSTRAINT PK_AUDIT_LOG PRIMARY KEY,
  tenant_id    UNIQUEIDENTIFIER NULL, -- null allowed for system/ops events
  table_name   NVARCHAR(128)    NOT NULL,
  record_id    UNIQUEIDENTIFIER NULL,
  operation    NVARCHAR(10)     NOT NULL, -- INSERT/UPDATE/DELETE
  old_values   NVARCHAR(MAX)    NULL,
  new_values   NVARCHAR(MAX)    NULL,
  changed_by   UNIQUEIDENTIFIER NULL,
  change_date  DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  session_id   NVARCHAR(100)    NULL,
  ip_address   NVARCHAR(64)     NULL,
  created_at   DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at   DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  is_deleted   BIT              NOT NULL DEFAULT 0,
  version      ROWVERSION
);

CREATE TABLE OPS.OUTBOX_EVENT (
  id            UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() CONSTRAINT PK_OUTBOX_EVENT PRIMARY KEY,
  tenant_id     UNIQUEIDENTIFIER NOT NULL,
  event_type    NVARCHAR(100)    NOT NULL,
  event_data    NVARCHAR(MAX)    NOT NULL,
  status        NVARCHAR(30)     NOT NULL DEFAULT N'PENDING', -- PENDING|SENT|FAILED
  retry_count   INT              NOT NULL DEFAULT 0,
  created_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  processed_at  DATETIME2        NULL,
  updated_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  is_deleted    BIT              NOT NULL DEFAULT 0,
  version       ROWVERSION
);

CREATE TABLE OPS.INTEGRATION_ENDPOINT (
  id                 UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() CONSTRAINT PK_INTEGRATION_ENDPOINT PRIMARY KEY,
  tenant_id          UNIQUEIDENTIFIER NOT NULL,
  endpoint_name      NVARCHAR(100)    NOT NULL,
  endpoint_type      NVARCHAR(50)     NOT NULL,
  endpoint_url       NVARCHAR(500)    NOT NULL,
  authentication_type NVARCHAR(50)    NOT NULL,
  configuration      NVARCHAR(MAX)    NULL,
  is_active          BIT              NOT NULL DEFAULT 1,
  created_at         DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at         DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  is_deleted         BIT              NOT NULL DEFAULT 0,
  version            ROWVERSION
);

-- DOCS
CREATE TABLE DOCS.DOCUMENT (
  id            UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() CONSTRAINT PK_DOCUMENT PRIMARY KEY,
  tenant_id     UNIQUEIDENTIFIER NOT NULL,
  document_name NVARCHAR(200)    NOT NULL,
  document_type NVARCHAR(50)     NOT NULL,
  file_path     NVARCHAR(500)    NOT NULL,
  file_size     BIGINT           NOT NULL,
  mime_type     NVARCHAR(100)    NOT NULL,
  uploaded_by   UNIQUEIDENTIFIER NULL,
  uploaded_at   DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  status        NVARCHAR(30)     NOT NULL DEFAULT N'ACTIVE',
  created_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at    DATETIME2        NOT NULL DEFAULT SYSUTCDATETIME(),
  is_deleted    BIT              NOT NULL DEFAULT 0,
  version       ROWVERSION
);
GO