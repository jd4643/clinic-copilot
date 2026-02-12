#!/usr/bin/env bash
set -euo pipefail

PROJECT="layaway-reminder-engine"
BASE_PKG="com/layaway/reminder"

echo "==> Creating $PROJECT ..."
rm -rf "$PROJECT"

# ── Directory structure ──────────────────────────────────────────────
mkdir -p "$PROJECT/src/main/java/$BASE_PKG/config"
mkdir -p "$PROJECT/src/main/java/$BASE_PKG/controller"
mkdir -p "$PROJECT/src/main/java/$BASE_PKG/dto"
mkdir -p "$PROJECT/src/main/java/$BASE_PKG/entity"
mkdir -p "$PROJECT/src/main/java/$BASE_PKG/enums"
mkdir -p "$PROJECT/src/main/java/$BASE_PKG/repository"
mkdir -p "$PROJECT/src/main/java/$BASE_PKG/service"
mkdir -p "$PROJECT/src/main/resources/db/migration"
mkdir -p "$PROJECT/src/test/java/$BASE_PKG"
mkdir -p "$PROJECT/src/test/resources"
mkdir -p "$PROJECT/samples"

# ── pom.xml ──────────────────────────────────────────────────────────
cat > "$PROJECT/pom.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.5</version>
        <relativePath/>
    </parent>

    <groupId>com.layaway</groupId>
    <artifactId>layaway-reminder-engine</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>layaway-reminder-engine</name>
    <description>Layaway Reminder Engine</description>

    <properties>
        <java.version>17</java.version>
        <twilio.version>10.1.0</twilio.version>
        <stripe.version>26.1.0</stripe.version>
        <opencsv.version>5.9</opencsv.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>

        <!-- Flyway -->
        <dependency>
            <groupId>org.flywaydb</groupId>
            <artifactId>flyway-core</artifactId>
        </dependency>
        <!-- Postgres -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>

        <!-- Twilio -->
        <dependency>
            <groupId>com.twilio.sdk</groupId>
            <artifactId>twilio</artifactId>
            <version>${twilio.version}</version>
        </dependency>

        <!-- Stripe -->
        <dependency>
            <groupId>com.stripe</groupId>
            <artifactId>stripe-java</artifactId>
            <version>${stripe.version}</version>
        </dependency>

        <!-- CSV -->
        <dependency>
            <groupId>com.opencsv</groupId>
            <artifactId>opencsv</artifactId>
            <version>${opencsv.version}</version>
        </dependency>

        <!-- Micrometer Prometheus (optional, good for metrics) -->
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
        </dependency>

        <!-- Test -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# ── docker-compose.yml ────────────────────────────────────────────────
cat > "$PROJECT/docker-compose.yml" <<'EOF'
version: "3.9"
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: layaway
      POSTGRES_USER: layaway
      POSTGRES_PASSWORD: layaway
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
EOF

# ── .gitignore ────────────────────────────────────────────────────────
cat > "$PROJECT/.gitignore" <<'EOF'
target/
*.class
*.jar
*.war
*.log
.idea/
*.iml
.DS_Store
.env
EOF

# ── application.yml ───────────────────────────────────────────────────
cat > "$PROJECT/src/main/resources/application.yml" <<'EOF'
spring:
  datasource:
    url: ${DB_URL:jdbc:postgresql://localhost:5432/layaway}
    username: ${DB_USERNAME:layaway}
    password: ${DB_PASSWORD:layaway}
    hikari:
      maximum-pool-size: 10
  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false
  flyway:
    enabled: true
    locations: classpath:db/migration

server:
  port: ${SERVER_PORT:8080}

app:
  admin-api-key: ${APP_ADMIN_API_KEY:change-me-in-production}
  reminder-cron: ${APP_REMINDER_CRON:0 0 10 * * *}
  store-timezone: ${APP_STORE_TIMEZONE:America/Chicago}
  sms-rate-per-second: ${APP_SMS_RATE_PER_SECOND:5}
  base-url: ${APP_BASE_URL:http://localhost:8080}

twilio:
  account-sid: ${TWILIO_ACCOUNT_SID:}
  auth-token: ${TWILIO_AUTH_TOKEN:}
  from-phone: ${TWILIO_FROM_PHONE:}

stripe:
  api-key: ${STRIPE_API_KEY:}
  webhook-secret: ${STRIPE_WEBHOOK_SECRET:}

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  metrics:
    tags:
      application: layaway-reminder-engine
EOF

# ── application-local.yml ─────────────────────────────────────────────
cat > "$PROJECT/src/main/resources/application-local.yml" <<'EOF'
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/layaway
    username: layaway
    password: layaway
  jpa:
    show-sql: true

logging:
  level:
    com.layaway.reminder: DEBUG
    org.hibernate.SQL: DEBUG
EOF

# ── application-test.yml (test resources) ─────────────────────────────
cat > "$PROJECT/src/test/resources/application-test.yml" <<'EOF'
spring:
  datasource:
    url: jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1;MODE=PostgreSQL
    driver-class-name: org.h2.Driver
    username: sa
    password:
  jpa:
    hibernate:
      ddl-auto: create-drop
    database-platform: org.hibernate.dialect.H2Dialect
  flyway:
    enabled: false

app:
  admin-api-key: test-api-key
  reminder-cron: "0 0 10 * * *"
  store-timezone: America/Chicago
  sms-rate-per-second: 100
  base-url: http://localhost:8080

twilio:
  account-sid: test-sid
  auth-token: test-token
  from-phone: "+15551234567"

stripe:
  api-key: sk_test_fake
  webhook-secret: whsec_test_fake
EOF

# ── V1__init.sql ─────────────────────────────────────────────────────
cat > "$PROJECT/src/main/resources/db/migration/V1__init.sql" <<'EOF'
-- =====================================================================
-- Layaway Reminder Engine – initial schema
-- =====================================================================

CREATE TABLE store (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    phone           VARCHAR(20),
    timezone        VARCHAR(50)  NOT NULL DEFAULT 'America/Chicago',
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE TABLE store_csv_mapping (
    id              BIGSERIAL PRIMARY KEY,
    store_id        BIGINT       NOT NULL REFERENCES store(id),
    mapping_json    JSONB        NOT NULL,
    updated_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_store_csv_mapping_store UNIQUE (store_id)
);

CREATE TABLE layaway (
    id                    BIGSERIAL      PRIMARY KEY,
    store_id              BIGINT         NOT NULL REFERENCES store(id),
    external_layaway_id   VARCHAR(255)   NOT NULL,
    customer_name         VARCHAR(255)   NOT NULL,
    phone                 VARCHAR(20)    NOT NULL,
    created_date          DATE           NOT NULL,
    last_payment_date     DATE,
    balance               NUMERIC(12,2)  NOT NULL DEFAULT 0,
    status                VARCHAR(20)    NOT NULL DEFAULT 'ACTIVE',
    inactive              BOOLEAN        NOT NULL DEFAULT FALSE,
    reminder_paused       BOOLEAN        NOT NULL DEFAULT FALSE,
    needs_manual_review   BOOLEAN        NOT NULL DEFAULT FALSE,
    contact_invalid       BOOLEAN        NOT NULL DEFAULT FALSE,
    created_at            TIMESTAMP      NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMP      NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_layaway_store_external UNIQUE (store_id, external_layaway_id)
);

CREATE TABLE import_job (
    id              BIGSERIAL    PRIMARY KEY,
    store_id        BIGINT       NOT NULL REFERENCES store(id),
    filename        VARCHAR(255),
    total_rows      INTEGER      NOT NULL DEFAULT 0,
    success_rows    INTEGER      NOT NULL DEFAULT 0,
    error_rows      INTEGER      NOT NULL DEFAULT 0,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    started_at      TIMESTAMP,
    completed_at    TIMESTAMP,
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE TABLE import_job_error (
    id              BIGSERIAL PRIMARY KEY,
    import_job_id   BIGINT    NOT NULL REFERENCES import_job(id),
    row_number      INTEGER,
    field           VARCHAR(255),
    error_message   TEXT,
    raw_data        TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE reminder_log (
    id              BIGSERIAL    PRIMARY KEY,
    layaway_id      BIGINT       NOT NULL REFERENCES layaway(id),
    store_id        BIGINT       NOT NULL REFERENCES store(id),
    reminder_date   DATE         NOT NULL,
    reminder_type   VARCHAR(30)  NOT NULL,
    days_to_due     INTEGER,
    twilio_sid      VARCHAR(255),
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    error_message   TEXT,
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_reminder_log_layaway_date_type UNIQUE (layaway_id, reminder_date, reminder_type)
);

CREATE TABLE outbound_message (
    id          BIGSERIAL    PRIMARY KEY,
    store_id    BIGINT       NOT NULL REFERENCES store(id),
    layaway_id  BIGINT       REFERENCES layaway(id),
    to_phone    VARCHAR(20)  NOT NULL,
    twilio_sid  VARCHAR(255),
    body        TEXT,
    sent_at     TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE TABLE inbound_message_log (
    id                  BIGSERIAL    PRIMARY KEY,
    from_phone          VARCHAR(20)  NOT NULL,
    to_phone            VARCHAR(20),
    body                TEXT,
    twilio_message_sid  VARCHAR(255),
    command             VARCHAR(20),
    layaway_id          BIGINT       REFERENCES layaway(id),
    processed           BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE TABLE call_task (
    id              BIGSERIAL    PRIMARY KEY,
    store_id        BIGINT       NOT NULL REFERENCES store(id),
    layaway_id      BIGINT       NOT NULL REFERENCES layaway(id),
    customer_name   VARCHAR(255),
    phone           VARCHAR(20),
    reason          VARCHAR(255),
    resolved        BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE TABLE payment_session (
    id          BIGSERIAL      PRIMARY KEY,
    store_id    BIGINT         NOT NULL REFERENCES store(id),
    layaway_id  BIGINT         NOT NULL REFERENCES layaway(id),
    token       VARCHAR(255)   NOT NULL UNIQUE,
    amount_min  NUMERIC(12,2),
    amount_max  NUMERIC(12,2),
    expires_at  TIMESTAMP      NOT NULL,
    used        BOOLEAN        NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP      NOT NULL DEFAULT NOW()
);

CREATE TABLE payment (
    id                          BIGSERIAL      PRIMARY KEY,
    store_id                    BIGINT         NOT NULL REFERENCES store(id),
    layaway_id                  BIGINT         NOT NULL REFERENCES layaway(id),
    payment_session_id          BIGINT         REFERENCES payment_session(id),
    amount                      NUMERIC(12,2)  NOT NULL,
    stripe_payment_intent_id    VARCHAR(255),
    stripe_checkout_session_id  VARCHAR(255),
    created_at                  TIMESTAMP      NOT NULL DEFAULT NOW()
);

CREATE TABLE stripe_event (
    id               BIGSERIAL    PRIMARY KEY,
    stripe_event_id  VARCHAR(255) NOT NULL UNIQUE,
    event_type       VARCHAR(100),
    processed        BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE TABLE sync_conflict (
    id             BIGSERIAL    PRIMARY KEY,
    store_id       BIGINT       NOT NULL REFERENCES store(id),
    layaway_id     BIGINT       NOT NULL REFERENCES layaway(id),
    import_job_id  BIGINT       REFERENCES import_job(id),
    field          VARCHAR(100),
    csv_value      TEXT,
    db_value       TEXT,
    resolution     VARCHAR(50),
    created_at     TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ── Indexes ─────────────────────────────────────────────────────────
CREATE INDEX idx_layaway_store_id        ON layaway(store_id);
CREATE INDEX idx_layaway_status          ON layaway(status);
CREATE INDEX idx_layaway_inactive        ON layaway(inactive);
CREATE INDEX idx_layaway_store_ext       ON layaway(store_id, external_layaway_id);
CREATE INDEX idx_reminder_log_lay_date   ON reminder_log(layaway_id, reminder_date);
CREATE INDEX idx_outbound_msg_phone_sent ON outbound_message(to_phone, sent_at DESC);
CREATE INDEX idx_payment_session_token   ON payment_session(token);
CREATE INDEX idx_inbound_msg_phone       ON inbound_message_log(from_phone);
CREATE INDEX idx_import_job_store        ON import_job(store_id);
CREATE INDEX idx_call_task_store         ON call_task(store_id, resolved);
CREATE INDEX idx_stripe_event_eid        ON stripe_event(stripe_event_id);
EOF

# ── Enums ────────────────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/enums/LayawayStatus.java" <<'EOF'
package com.layaway.reminder.enums;

public enum LayawayStatus {
    ACTIVE, PAID, CLOSED, CANCELLED
}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/enums/ReminderType.java" <<'EOF'
package com.layaway.reminder.enums;

public enum ReminderType {
    T_MINUS_3, DUE_TODAY, OVERDUE_EVERY_5
}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/enums/ImportJobStatus.java" <<'EOF'
package com.layaway.reminder.enums;

public enum ImportJobStatus {
    PENDING, PROCESSING, COMPLETED, FAILED
}
EOF

# ── Entity: Store ─────────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/Store.java" <<'EOF'
package com.layaway.reminder.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "store")
public class Store {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    private String phone;

    @Column(nullable = false)
    private String timezone = "America/Chicago";

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public String getTimezone() { return timezone; }
    public void setTimezone(String timezone) { this.timezone = timezone; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
EOF

# ── Entity: StoreCsvMapping ──────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/StoreCsvMapping.java" <<'EOF'
package com.layaway.reminder.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "store_csv_mapping")
public class StoreCsvMapping {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "store_id", nullable = false, unique = true)
    private Long storeId;

    @Column(name = "mapping_json", nullable = false, columnDefinition = "jsonb")
    private String mappingJson;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getStoreId() { return storeId; }
    public void setStoreId(Long storeId) { this.storeId = storeId; }
    public String getMappingJson() { return mappingJson; }
    public void setMappingJson(String mappingJson) { this.mappingJson = mappingJson; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
EOF

# ── Entity: Layaway ──────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/Layaway.java" <<'EOF'
package com.layaway.reminder.entity;

import com.layaway.reminder.enums.LayawayStatus;
import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "layaway",
       uniqueConstraints = @UniqueConstraint(columnNames = {"store_id", "external_layaway_id"}))
public class Layaway {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "store_id", nullable = false)
    private Long storeId;

    @Column(name = "external_layaway_id", nullable = false)
    private String externalLayawayId;

    @Column(name = "customer_name", nullable = false)
    private String customerName;

    @Column(nullable = false)
    private String phone;

    @Column(name = "created_date", nullable = false)
    private LocalDate createdDate;

    @Column(name = "last_payment_date")
    private LocalDate lastPaymentDate;

    @Column(nullable = false)
    private BigDecimal balance = BigDecimal.ZERO;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private LayawayStatus status = LayawayStatus.ACTIVE;

    @Column(nullable = false)
    private Boolean inactive = false;

    @Column(name = "reminder_paused", nullable = false)
    private Boolean reminderPaused = false;

    @Column(name = "needs_manual_review", nullable = false)
    private Boolean needsManualReview = false;

    @Column(name = "contact_invalid", nullable = false)
    private Boolean contactInvalid = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    // Getters & Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getStoreId() { return storeId; }
    public void setStoreId(Long storeId) { this.storeId = storeId; }
    public String getExternalLayawayId() { return externalLayawayId; }
    public void setExternalLayawayId(String externalLayawayId) { this.externalLayawayId = externalLayawayId; }
    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public LocalDate getCreatedDate() { return createdDate; }
    public void setCreatedDate(LocalDate createdDate) { this.createdDate = createdDate; }
    public LocalDate getLastPaymentDate() { return lastPaymentDate; }
    public void setLastPaymentDate(LocalDate lastPaymentDate) { this.lastPaymentDate = lastPaymentDate; }
    public BigDecimal getBalance() { return balance; }
    public void setBalance(BigDecimal balance) { this.balance = balance; }
    public LayawayStatus getStatus() { return status; }
    public void setStatus(LayawayStatus status) { this.status = status; }
    public Boolean getInactive() { return inactive; }
    public void setInactive(Boolean inactive) { this.inactive = inactive; }
    public Boolean getReminderPaused() { return reminderPaused; }
    public void setReminderPaused(Boolean reminderPaused) { this.reminderPaused = reminderPaused; }
    public Boolean getNeedsManualReview() { return needsManualReview; }
    public void setNeedsManualReview(Boolean needsManualReview) { this.needsManualReview = needsManualReview; }
    public Boolean getContactInvalid() { return contactInvalid; }
    public void setContactInvalid(Boolean contactInvalid) { this.contactInvalid = contactInvalid; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
EOF

# ── Entity: ImportJob ────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/ImportJob.java" <<'EOF'
package com.layaway.reminder.entity;

import com.layaway.reminder.enums.ImportJobStatus;
import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "import_job")
public class ImportJob {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "store_id", nullable = false)
    private Long storeId;

    private String filename;

    @Column(name = "total_rows", nullable = false)
    private Integer totalRows = 0;

    @Column(name = "success_rows", nullable = false)
    private Integer successRows = 0;

    @Column(name = "error_rows", nullable = false)
    private Integer errorRows = 0;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ImportJobStatus status = ImportJobStatus.PENDING;

    @Column(name = "started_at")
    private Instant startedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getStoreId() { return storeId; }
    public void setStoreId(Long storeId) { this.storeId = storeId; }
    public String getFilename() { return filename; }
    public void setFilename(String filename) { this.filename = filename; }
    public Integer getTotalRows() { return totalRows; }
    public void setTotalRows(Integer totalRows) { this.totalRows = totalRows; }
    public Integer getSuccessRows() { return successRows; }
    public void setSuccessRows(Integer successRows) { this.successRows = successRows; }
    public Integer getErrorRows() { return errorRows; }
    public void setErrorRows(Integer errorRows) { this.errorRows = errorRows; }
    public ImportJobStatus getStatus() { return status; }
    public void setStatus(ImportJobStatus status) { this.status = status; }
    public Instant getStartedAt() { return startedAt; }
    public void setStartedAt(Instant startedAt) { this.startedAt = startedAt; }
    public Instant getCompletedAt() { return completedAt; }
    public void setCompletedAt(Instant completedAt) { this.completedAt = completedAt; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
EOF

# ── Entity: ImportJobError ───────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/ImportJobError.java" <<'EOF'
package com.layaway.reminder.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "import_job_error")
public class ImportJobError {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "import_job_id", nullable = false)
    private Long importJobId;

    @Column(name = "row_number")
    private Integer rowNumber;

    private String field;

    @Column(name = "error_message")
    private String errorMessage;

    @Column(name = "raw_data")
    private String rawData;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getImportJobId() { return importJobId; }
    public void setImportJobId(Long importJobId) { this.importJobId = importJobId; }
    public Integer getRowNumber() { return rowNumber; }
    public void setRowNumber(Integer rowNumber) { this.rowNumber = rowNumber; }
    public String getField() { return field; }
    public void setField(String field) { this.field = field; }
    public String getErrorMessage() { return errorMessage; }
    public void setErrorMessage(String errorMessage) { this.errorMessage = errorMessage; }
    public String getRawData() { return rawData; }
    public void setRawData(String rawData) { this.rawData = rawData; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
EOF

# ── Entity: ReminderLog ──────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/ReminderLog.java" <<'EOF'
package com.layaway.reminder.entity;

import com.layaway.reminder.enums.ReminderType;
import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "reminder_log",
       uniqueConstraints = @UniqueConstraint(columnNames = {"layaway_id", "reminder_date", "reminder_type"}))
public class ReminderLog {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "layaway_id", nullable = false)
    private Long layawayId;

    @Column(name = "store_id", nullable = false)
    private Long storeId;

    @Column(name = "reminder_date", nullable = false)
    private LocalDate reminderDate;

    @Enumerated(EnumType.STRING)
    @Column(name = "reminder_type", nullable = false)
    private ReminderType reminderType;

    @Column(name = "days_to_due")
    private Integer daysToDue;

    @Column(name = "twilio_sid")
    private String twilioSid;

    @Column(nullable = false)
    private String status = "PENDING";

    @Column(name = "error_message")
    private String errorMessage;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getLayawayId() { return layawayId; }
    public void setLayawayId(Long layawayId) { this.layawayId = layawayId; }
    public Long getStoreId() { return storeId; }
    public void setStoreId(Long storeId) { this.storeId = storeId; }
    public LocalDate getReminderDate() { return reminderDate; }
    public void setReminderDate(LocalDate reminderDate) { this.reminderDate = reminderDate; }
    public ReminderType getReminderType() { return reminderType; }
    public void setReminderType(ReminderType reminderType) { this.reminderType = reminderType; }
    public Integer getDaysToDue() { return daysToDue; }
    public void setDaysToDue(Integer daysToDue) { this.daysToDue = daysToDue; }
    public String getTwilioSid() { return twilioSid; }
    public void setTwilioSid(String twilioSid) { this.twilioSid = twilioSid; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getErrorMessage() { return errorMessage; }
    public void setErrorMessage(String errorMessage) { this.errorMessage = errorMessage; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
EOF

# ── Entity: OutboundMessage ──────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/OutboundMessage.java" <<'EOF'
package com.layaway.reminder.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "outbound_message")
public class OutboundMessage {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "store_id", nullable = false)
    private Long storeId;

    @Column(name = "layaway_id")
    private Long layawayId;

    @Column(name = "to_phone", nullable = false)
    private String toPhone;

    @Column(name = "twilio_sid")
    private String twilioSid;

    private String body;

    @Column(name = "sent_at", nullable = false)
    private Instant sentAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getStoreId() { return storeId; }
    public void setStoreId(Long storeId) { this.storeId = storeId; }
    public Long getLayawayId() { return layawayId; }
    public void setLayawayId(Long layawayId) { this.layawayId = layawayId; }
    public String getToPhone() { return toPhone; }
    public void setToPhone(String toPhone) { this.toPhone = toPhone; }
    public String getTwilioSid() { return twilioSid; }
    public void setTwilioSid(String twilioSid) { this.twilioSid = twilioSid; }
    public String getBody() { return body; }
    public void setBody(String body) { this.body = body; }
    public Instant getSentAt() { return sentAt; }
    public void setSentAt(Instant sentAt) { this.sentAt = sentAt; }
}
EOF

# ── Entity: InboundMessageLog ────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/InboundMessageLog.java" <<'EOF'
package com.layaway.reminder.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "inbound_message_log")
public class InboundMessageLog {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "from_phone", nullable = false)
    private String fromPhone;

    @Column(name = "to_phone")
    private String toPhone;

    private String body;

    @Column(name = "twilio_message_sid")
    private String twilioMessageSid;

    private String command;

    @Column(name = "layaway_id")
    private Long layawayId;

    @Column(nullable = false)
    private Boolean processed = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getFromPhone() { return fromPhone; }
    public void setFromPhone(String fromPhone) { this.fromPhone = fromPhone; }
    public String getToPhone() { return toPhone; }
    public void setToPhone(String toPhone) { this.toPhone = toPhone; }
    public String getBody() { return body; }
    public void setBody(String body) { this.body = body; }
    public String getTwilioMessageSid() { return twilioMessageSid; }
    public void setTwilioMessageSid(String twilioMessageSid) { this.twilioMessageSid = twilioMessageSid; }
    public String getCommand() { return command; }
    public void setCommand(String command) { this.command = command; }
    public Long getLayawayId() { return layawayId; }
    public void setLayawayId(Long layawayId) { this.layawayId = layawayId; }
    public Boolean getProcessed() { return processed; }
    public void setProcessed(Boolean processed) { this.processed = processed; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
EOF

# ── Entity: CallTask ─────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/CallTask.java" <<'EOF'
package com.layaway.reminder.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "call_task")
public class CallTask {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "store_id", nullable = false)
    private Long storeId;

    @Column(name = "layaway_id", nullable = false)
    private Long layawayId;

    @Column(name = "customer_name")
    private String customerName;

    private String phone;
    private String reason;

    @Column(nullable = false)
    private Boolean resolved = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getStoreId() { return storeId; }
    public void setStoreId(Long storeId) { this.storeId = storeId; }
    public Long getLayawayId() { return layawayId; }
    public void setLayawayId(Long layawayId) { this.layawayId = layawayId; }
    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
    public Boolean getResolved() { return resolved; }
    public void setResolved(Boolean resolved) { this.resolved = resolved; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
EOF

# ── Entity: PaymentSession ───────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/PaymentSession.java" <<'EOF'
package com.layaway.reminder.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "payment_session")
public class PaymentSession {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "store_id", nullable = false)
    private Long storeId;

    @Column(name = "layaway_id", nullable = false)
    private Long layawayId;

    @Column(nullable = false, unique = true)
    private String token;

    @Column(name = "amount_min")
    private BigDecimal amountMin;

    @Column(name = "amount_max")
    private BigDecimal amountMax;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(nullable = false)
    private Boolean used = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getStoreId() { return storeId; }
    public void setStoreId(Long storeId) { this.storeId = storeId; }
    public Long getLayawayId() { return layawayId; }
    public void setLayawayId(Long layawayId) { this.layawayId = layawayId; }
    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }
    public BigDecimal getAmountMin() { return amountMin; }
    public void setAmountMin(BigDecimal amountMin) { this.amountMin = amountMin; }
    public BigDecimal getAmountMax() { return amountMax; }
    public void setAmountMax(BigDecimal amountMax) { this.amountMax = amountMax; }
    public Instant getExpiresAt() { return expiresAt; }
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }
    public Boolean getUsed() { return used; }
    public void setUsed(Boolean used) { this.used = used; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
EOF

# ── Entity: Payment ──────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/Payment.java" <<'EOF'
package com.layaway.reminder.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "payment")
public class Payment {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "store_id", nullable = false)
    private Long storeId;

    @Column(name = "layaway_id", nullable = false)
    private Long layawayId;

    @Column(name = "payment_session_id")
    private Long paymentSessionId;

    @Column(nullable = false)
    private BigDecimal amount;

    @Column(name = "stripe_payment_intent_id")
    private String stripePaymentIntentId;

    @Column(name = "stripe_checkout_session_id")
    private String stripeCheckoutSessionId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getStoreId() { return storeId; }
    public void setStoreId(Long storeId) { this.storeId = storeId; }
    public Long getLayawayId() { return layawayId; }
    public void setLayawayId(Long layawayId) { this.layawayId = layawayId; }
    public Long getPaymentSessionId() { return paymentSessionId; }
    public void setPaymentSessionId(Long paymentSessionId) { this.paymentSessionId = paymentSessionId; }
    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }
    public String getStripePaymentIntentId() { return stripePaymentIntentId; }
    public void setStripePaymentIntentId(String stripePaymentIntentId) { this.stripePaymentIntentId = stripePaymentIntentId; }
    public String getStripeCheckoutSessionId() { return stripeCheckoutSessionId; }
    public void setStripeCheckoutSessionId(String stripeCheckoutSessionId) { this.stripeCheckoutSessionId = stripeCheckoutSessionId; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
EOF

# ── Entity: StripeEvent ──────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/StripeEvent.java" <<'EOF'
package com.layaway.reminder.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "stripe_event")
public class StripeEvent {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "stripe_event_id", nullable = false, unique = true)
    private String stripeEventId;

    @Column(name = "event_type")
    private String eventType;

    @Column(nullable = false)
    private Boolean processed = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getStripeEventId() { return stripeEventId; }
    public void setStripeEventId(String stripeEventId) { this.stripeEventId = stripeEventId; }
    public String getEventType() { return eventType; }
    public void setEventType(String eventType) { this.eventType = eventType; }
    public Boolean getProcessed() { return processed; }
    public void setProcessed(Boolean processed) { this.processed = processed; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
EOF

# ── Entity: SyncConflict ─────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/entity/SyncConflict.java" <<'EOF'
package com.layaway.reminder.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "sync_conflict")
public class SyncConflict {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "store_id", nullable = false)
    private Long storeId;

    @Column(name = "layaway_id", nullable = false)
    private Long layawayId;

    @Column(name = "import_job_id")
    private Long importJobId;

    private String field;

    @Column(name = "csv_value")
    private String csvValue;

    @Column(name = "db_value")
    private String dbValue;

    private String resolution;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getStoreId() { return storeId; }
    public void setStoreId(Long storeId) { this.storeId = storeId; }
    public Long getLayawayId() { return layawayId; }
    public void setLayawayId(Long layawayId) { this.layawayId = layawayId; }
    public Long getImportJobId() { return importJobId; }
    public void setImportJobId(Long importJobId) { this.importJobId = importJobId; }
    public String getField() { return field; }
    public void setField(String field) { this.field = field; }
    public String getCsvValue() { return csvValue; }
    public void setCsvValue(String csvValue) { this.csvValue = csvValue; }
    public String getDbValue() { return dbValue; }
    public void setDbValue(String dbValue) { this.dbValue = dbValue; }
    public String getResolution() { return resolution; }
    public void setResolution(String resolution) { this.resolution = resolution; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
EOF

# ── Repositories ─────────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/repository/StoreRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.Store;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StoreRepository extends JpaRepository<Store, Long> {}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/StoreCsvMappingRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.StoreCsvMapping;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface StoreCsvMappingRepository extends JpaRepository<StoreCsvMapping, Long> {
    Optional<StoreCsvMapping> findByStoreId(Long storeId);
}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/LayawayRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.Layaway;
import com.layaway.reminder.enums.LayawayStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface LayawayRepository extends JpaRepository<Layaway, Long> {

    Optional<Layaway> findByStoreIdAndExternalLayawayId(Long storeId, String externalLayawayId);

    @Modifying
    @Query("UPDATE Layaway l SET l.inactive = true WHERE l.storeId = :storeId")
    int markAllInactiveForStore(@Param("storeId") Long storeId);

    @Query("SELECT l FROM Layaway l WHERE l.inactive = false AND l.balance > 0 " +
           "AND l.reminderPaused = false AND l.needsManualReview = false " +
           "AND l.contactInvalid = false AND l.status = :status")
    List<Layaway> findEligibleForReminder(@Param("status") LayawayStatus status);

    List<Layaway> findByNeedsManualReviewTrue();

    List<Layaway> findByPhoneAndInactiveFalseAndStatus(String phone, LayawayStatus status);
}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/ImportJobRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.ImportJob;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ImportJobRepository extends JpaRepository<ImportJob, Long> {}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/ImportJobErrorRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.ImportJobError;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ImportJobErrorRepository extends JpaRepository<ImportJobError, Long> {
    List<ImportJobError> findByImportJobId(Long importJobId);
}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/ReminderLogRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.ReminderLog;
import com.layaway.reminder.enums.ReminderType;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;

public interface ReminderLogRepository extends JpaRepository<ReminderLog, Long> {
    boolean existsByLayawayIdAndReminderDateAndReminderType(Long layawayId, LocalDate reminderDate, ReminderType reminderType);
    List<ReminderLog> findByReminderDate(LocalDate reminderDate);
}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/OutboundMessageRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.OutboundMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.Instant;
import java.util.List;

public interface OutboundMessageRepository extends JpaRepository<OutboundMessage, Long> {

    @Query("SELECT o FROM OutboundMessage o WHERE o.toPhone = :phone AND o.sentAt >= :since ORDER BY o.sentAt DESC")
    List<OutboundMessage> findRecentByPhone(@Param("phone") String phone, @Param("since") Instant since);
}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/InboundMessageLogRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.InboundMessageLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface InboundMessageLogRepository extends JpaRepository<InboundMessageLog, Long> {}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/CallTaskRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.CallTask;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface CallTaskRepository extends JpaRepository<CallTask, Long> {
    List<CallTask> findByStoreIdAndResolvedFalse(Long storeId);
    List<CallTask> findByResolvedFalse();
}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/PaymentSessionRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.PaymentSession;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface PaymentSessionRepository extends JpaRepository<PaymentSession, Long> {
    Optional<PaymentSession> findByToken(String token);
}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/PaymentRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.Payment;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentRepository extends JpaRepository<Payment, Long> {}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/StripeEventRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.StripeEvent;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StripeEventRepository extends JpaRepository<StripeEvent, Long> {
    boolean existsByStripeEventId(String stripeEventId);
}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/repository/SyncConflictRepository.java" <<'EOF'
package com.layaway.reminder.repository;

import com.layaway.reminder.entity.SyncConflict;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SyncConflictRepository extends JpaRepository<SyncConflict, Long> {}
EOF

# ── DTOs ─────────────────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/dto/CsvMappingDto.java" <<'EOF'
package com.layaway.reminder.dto;

import java.util.Map;

public record CsvMappingDto(Map<String, String> mapping) {}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/dto/ImportSummaryDto.java" <<'EOF'
package com.layaway.reminder.dto;

import java.util.List;

public record ImportSummaryDto(
    Long importJobId,
    int totalRows,
    int successRows,
    int errorRows,
    List<String> errors
) {}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/dto/MappingSuggestionDto.java" <<'EOF'
package com.layaway.reminder.dto;

import java.util.List;
import java.util.Map;

public record MappingSuggestionDto(
    String message,
    List<String> csvHeaders,
    Map<String, String> suggestions
) {}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/dto/PaymentPageDto.java" <<'EOF'
package com.layaway.reminder.dto;

import java.math.BigDecimal;

public record PaymentPageDto(
    String customerName,
    String externalLayawayId,
    BigDecimal balance,
    BigDecimal minAmount,
    BigDecimal maxAmount,
    String token
) {}
EOF

cat > "$PROJECT/src/main/java/$BASE_PKG/dto/CheckoutRequestDto.java" <<'EOF'
package com.layaway.reminder.dto;

import java.math.BigDecimal;

public record CheckoutRequestDto(BigDecimal amount) {}
EOF

# ── Main Application ──────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/LayawayReminderEngineApplication.java" <<'EOF'
package com.layaway.reminder;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class LayawayReminderEngineApplication {
    public static void main(String[] args) {
        SpringApplication.run(LayawayReminderEngineApplication.class, args);
    }
}
EOF

# ── AppProperties ────────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/config/AppProperties.java" <<'EOF'
package com.layaway.reminder.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "app")
public class AppProperties {
    private String adminApiKey;
    private String reminderCron;
    private String storeTimezone = "America/Chicago";
    private int smsRatePerSecond = 5;
    private String baseUrl = "http://localhost:8080";

    public String getAdminApiKey() { return adminApiKey; }
    public void setAdminApiKey(String adminApiKey) { this.adminApiKey = adminApiKey; }
    public String getReminderCron() { return reminderCron; }
    public void setReminderCron(String reminderCron) { this.reminderCron = reminderCron; }
    public String getStoreTimezone() { return storeTimezone; }
    public void setStoreTimezone(String storeTimezone) { this.storeTimezone = storeTimezone; }
    public int getSmsRatePerSecond() { return smsRatePerSecond; }
    public void setSmsRatePerSecond(int smsRatePerSecond) { this.smsRatePerSecond = smsRatePerSecond; }
    public String getBaseUrl() { return baseUrl; }
    public void setBaseUrl(String baseUrl) { this.baseUrl = baseUrl; }
}
EOF

# ── TwilioProperties ────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/config/TwilioProperties.java" <<'EOF'
package com.layaway.reminder.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "twilio")
public class TwilioProperties {
    private String accountSid;
    private String authToken;
    private String fromPhone;

    public String getAccountSid() { return accountSid; }
    public void setAccountSid(String accountSid) { this.accountSid = accountSid; }
    public String getAuthToken() { return authToken; }
    public void setAuthToken(String authToken) { this.authToken = authToken; }
    public String getFromPhone() { return fromPhone; }
    public void setFromPhone(String fromPhone) { this.fromPhone = fromPhone; }
}
EOF

# ── StripeProperties ────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/config/StripeProperties.java" <<'EOF'
package com.layaway.reminder.config;

import com.stripe.Stripe;
import jakarta.annotation.PostConstruct;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "stripe")
public class StripeProperties {
    private String apiKey;
    private String webhookSecret;

    @PostConstruct
    public void init() {
        if (apiKey != null && !apiKey.isBlank()) {
            Stripe.apiKey = apiKey;
        }
    }

    public String getApiKey() { return apiKey; }
    public void setApiKey(String apiKey) { this.apiKey = apiKey; }
    public String getWebhookSecret() { return webhookSecret; }
    public void setWebhookSecret(String webhookSecret) { this.webhookSecret = webhookSecret; }
}
EOF

# ── ApiKeyFilter ─────────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/config/ApiKeyFilter.java" <<'EOF'
package com.layaway.reminder.config;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
@Order(1)
public class ApiKeyFilter implements Filter {

    private final AppProperties appProperties;

    public ApiKeyFilter(AppProperties appProperties) {
        this.appProperties = appProperties;
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest httpReq = (HttpServletRequest) request;
        String path = httpReq.getRequestURI();

        // Only protect /api/admin/** endpoints
        if (path.startsWith("/api/admin")) {
            String apiKey = httpReq.getHeader("X-API-KEY");
            if (apiKey == null || !apiKey.equals(appProperties.getAdminApiKey())) {
                HttpServletResponse httpResp = (HttpServletResponse) response;
                httpResp.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                httpResp.getWriter().write("{\"error\":\"Invalid or missing API key\"}");
                httpResp.setContentType("application/json");
                return;
            }
        }

        chain.doFilter(request, response);
    }
}
EOF

# ── CorrelationIdFilter ─────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/config/CorrelationIdFilter.java" <<'EOF'
package com.layaway.reminder.config;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.UUID;

@Component
@Order(0)
public class CorrelationIdFilter implements Filter {

    private static final String CORRELATION_ID_HEADER = "X-Correlation-ID";
    private static final String MDC_KEY = "correlationId";

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest httpReq = (HttpServletRequest) request;
        String correlationId = httpReq.getHeader(CORRELATION_ID_HEADER);
        if (correlationId == null || correlationId.isBlank()) {
            correlationId = UUID.randomUUID().toString();
        }
        MDC.put(MDC_KEY, correlationId);
        try {
            HttpServletResponse httpResp = (HttpServletResponse) response;
            httpResp.setHeader(CORRELATION_ID_HEADER, correlationId);
            chain.doFilter(request, response);
        } finally {
            MDC.remove(MDC_KEY);
        }
    }
}
EOF

# ── MetricsConfig ────────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/config/MetricsConfig.java" <<'EOF'
package com.layaway.reminder.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MetricsConfig {

    @Bean
    public Counter remindersSentCounter(MeterRegistry registry) {
        return Counter.builder("reminders_sent_total")
                .description("Total reminders sent")
                .register(registry);
    }

    @Bean
    public Counter remindersFailedCounter(MeterRegistry registry) {
        return Counter.builder("reminders_failed_total")
                .description("Total reminders failed")
                .register(registry);
    }

    @Bean
    public Counter paymentsCompletedCounter(MeterRegistry registry) {
        return Counter.builder("payments_completed_total")
                .description("Total payments completed")
                .register(registry);
    }
}
EOF

# ── SmsRateLimiter ───────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/service/SmsRateLimiter.java" <<'EOF'
package com.layaway.reminder.service;

import com.layaway.reminder.config.AppProperties;
import org.springframework.stereotype.Component;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Simple token-bucket rate limiter for SMS (in-memory, MVP).
 */
@Component
public class SmsRateLimiter {

    private final int ratePerSecond;
    private final AtomicLong tokens;
    private volatile long lastRefillTime;

    public SmsRateLimiter(AppProperties props) {
        this.ratePerSecond = props.getSmsRatePerSecond();
        this.tokens = new AtomicLong(ratePerSecond);
        this.lastRefillTime = System.nanoTime();
    }

    public synchronized boolean tryAcquire() {
        refill();
        if (tokens.get() > 0) {
            tokens.decrementAndGet();
            return true;
        }
        return false;
    }

    public synchronized void waitForPermit() throws InterruptedException {
        while (!tryAcquire()) {
            Thread.sleep(100);
        }
    }

    private void refill() {
        long now = System.nanoTime();
        long elapsed = now - lastRefillTime;
        long newTokens = (elapsed / 1_000_000_000L) * ratePerSecond;
        if (newTokens > 0) {
            tokens.set(Math.min(ratePerSecond, tokens.get() + newTokens));
            lastRefillTime = now;
        }
    }
}
EOF

# ── PhoneUtils ───────────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/service/PhoneUtils.java" <<'EOF'
package com.layaway.reminder.service;

/**
 * Phone normalization utility for US E.164 format.
 */
public final class PhoneUtils {

    private PhoneUtils() {}

    /**
     * Normalize a US phone number to E.164 format (+1XXXXXXXXXX).
     * Returns null if the number cannot be normalized.
     */
    public static String normalizeToE164(String raw) {
        if (raw == null) return null;
        String digits = raw.replaceAll("[^0-9]", "");
        if (digits.length() == 10) {
            return "+1" + digits;
        } else if (digits.length() == 11 && digits.startsWith("1")) {
            return "+" + digits;
        }
        return null;
    }
}
EOF

# ── TwilioService ───────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/service/TwilioService.java" <<'EOF'
package com.layaway.reminder.service;

import com.layaway.reminder.config.TwilioProperties;
import com.layaway.reminder.entity.OutboundMessage;
import com.layaway.reminder.repository.OutboundMessageRepository;
import com.twilio.Twilio;
import com.twilio.exception.ApiException;
import com.twilio.rest.api.v2010.account.Message;
import com.twilio.type.PhoneNumber;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;

@Service
public class TwilioService {

    private static final Logger log = LoggerFactory.getLogger(TwilioService.class);

    private final TwilioProperties twilioProperties;
    private final OutboundMessageRepository outboundMessageRepository;
    private final SmsRateLimiter rateLimiter;

    public TwilioService(TwilioProperties twilioProperties,
                         OutboundMessageRepository outboundMessageRepository,
                         SmsRateLimiter rateLimiter) {
        this.twilioProperties = twilioProperties;
        this.outboundMessageRepository = outboundMessageRepository;
        this.rateLimiter = rateLimiter;
    }

    @PostConstruct
    public void init() {
        if (twilioProperties.getAccountSid() != null && !twilioProperties.getAccountSid().isBlank()) {
            Twilio.init(twilioProperties.getAccountSid(), twilioProperties.getAuthToken());
        }
    }

    /**
     * Send SMS with retry on transient failures. Includes STOP instructions.
     */
    public SendResult sendSms(Long storeId, Long layawayId, String toPhone, String bodyText) {
        String fullBody = bodyText + "\n\nReply STOP to pause reminders.";
        int maxRetries = 3;

        for (int attempt = 0; attempt < maxRetries; attempt++) {
            try {
                rateLimiter.waitForPermit();
                Message msg = Message.creator(
                        new PhoneNumber(toPhone),
                        new PhoneNumber(twilioProperties.getFromPhone()),
                        fullBody
                ).create();

                OutboundMessage om = new OutboundMessage();
                om.setStoreId(storeId);
                om.setLayawayId(layawayId);
                om.setToPhone(toPhone);
                om.setTwilioSid(msg.getSid());
                om.setBody(fullBody);
                om.setSentAt(Instant.now());
                outboundMessageRepository.save(om);

                return new SendResult(true, msg.getSid(), null, false);
            } catch (ApiException e) {
                // Error codes for invalid numbers
                if (e.getCode() != null && (e.getCode() == 21211 || e.getCode() == 21614 || e.getCode() == 21217)) {
                    log.warn("Invalid phone number {}: {}", toPhone, e.getMessage());
                    return new SendResult(false, null, e.getMessage(), true);
                }
                if (attempt < maxRetries - 1) {
                    log.warn("Twilio transient error (attempt {}): {}", attempt + 1, e.getMessage());
                    try {
                        Thread.sleep((long) Math.pow(2, attempt) * 1000);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        return new SendResult(false, null, "Interrupted", false);
                    }
                } else {
                    log.error("Twilio send failed after {} attempts: {}", maxRetries, e.getMessage());
                    return new SendResult(false, null, e.getMessage(), false);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return new SendResult(false, null, "Interrupted", false);
            }
        }
        return new SendResult(false, null, "Max retries exhausted", false);
    }

    /** Send a simple reply (no STOP footer needed for system messages). */
    public void sendReply(String toPhone, String body) {
        try {
            rateLimiter.waitForPermit();
            Message.creator(
                    new PhoneNumber(toPhone),
                    new PhoneNumber(twilioProperties.getFromPhone()),
                    body
            ).create();
        } catch (Exception e) {
            log.error("Failed to send reply to {}: {}", toPhone, e.getMessage());
        }
    }

    public record SendResult(boolean success, String twilioSid, String errorMessage, boolean invalidNumber) {}
}
EOF

# ── ReminderService ──────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/service/ReminderService.java" <<'EOF'
package com.layaway.reminder.service;

import com.layaway.reminder.config.AppProperties;
import com.layaway.reminder.entity.Layaway;
import com.layaway.reminder.entity.ReminderLog;
import com.layaway.reminder.entity.Store;
import com.layaway.reminder.enums.LayawayStatus;
import com.layaway.reminder.enums.ReminderType;
import com.layaway.reminder.repository.LayawayRepository;
import com.layaway.reminder.repository.ReminderLogRepository;
import com.layaway.reminder.repository.StoreRepository;
import io.micrometer.core.instrument.Counter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class ReminderService {

    private static final Logger log = LoggerFactory.getLogger(ReminderService.class);

    private final LayawayRepository layawayRepository;
    private final ReminderLogRepository reminderLogRepository;
    private final StoreRepository storeRepository;
    private final TwilioService twilioService;
    private final AppProperties appProperties;
    private final Counter remindersSentCounter;
    private final Counter remindersFailedCounter;

    public ReminderService(LayawayRepository layawayRepository,
                           ReminderLogRepository reminderLogRepository,
                           StoreRepository storeRepository,
                           TwilioService twilioService,
                           AppProperties appProperties,
                           @Qualifier("remindersSentCounter") Counter remindersSentCounter,
                           @Qualifier("remindersFailedCounter") Counter remindersFailedCounter) {
        this.layawayRepository = layawayRepository;
        this.reminderLogRepository = reminderLogRepository;
        this.storeRepository = storeRepository;
        this.twilioService = twilioService;
        this.appProperties = appProperties;
        this.remindersSentCounter = remindersSentCounter;
        this.remindersFailedCounter = remindersFailedCounter;
    }

    @Scheduled(cron = "${app.reminder-cron}")
    public void runDailyReminders() {
        log.info("Starting daily reminder run...");
        List<Layaway> eligible = layawayRepository.findEligibleForReminder(LayawayStatus.ACTIVE);
        log.info("Found {} eligible layaways", eligible.size());

        for (Layaway layaway : eligible) {
            try {
                processLayaway(layaway);
            } catch (Exception e) {
                log.error("Error processing layaway {}: {}", layaway.getId(), e.getMessage());
            }
        }
        log.info("Daily reminder run complete.");
    }

    @Transactional
    public void processLayaway(Layaway layaway) {
        Store store = storeRepository.findById(layaway.getStoreId()).orElse(null);
        String tz = (store != null && store.getTimezone() != null) ? store.getTimezone() : appProperties.getStoreTimezone();
        LocalDate today = LocalDate.now(ZoneId.of(tz));

        ReminderType type = computeReminderType(layaway, today);
        if (type == null) {
            return; // no reminder needed today
        }

        long daysToDue = computeDaysToDue(layaway, today);

        // Check if needs manual review (overdue > 30 days)
        if (daysToDue < 0 && Math.abs(daysToDue) > 30) {
            layaway.setNeedsManualReview(true);
            layawayRepository.save(layaway);
            log.info("Layaway {} flagged for manual review (days overdue: {})", layaway.getId(), Math.abs(daysToDue));
            return;
        }

        // Idempotency: skip if already sent
        if (reminderLogRepository.existsByLayawayIdAndReminderDateAndReminderType(
                layaway.getId(), today, type)) {
            log.debug("Reminder already sent for layaway {} on {} type {}", layaway.getId(), today, type);
            return;
        }

        // Build message
        String message = buildMessage(layaway, type, daysToDue);

        // Send
        TwilioService.SendResult result = twilioService.sendSms(
                layaway.getStoreId(), layaway.getId(), layaway.getPhone(), message);

        // Log reminder
        ReminderLog rl = new ReminderLog();
        rl.setLayawayId(layaway.getId());
        rl.setStoreId(layaway.getStoreId());
        rl.setReminderDate(today);
        rl.setReminderType(type);
        rl.setDaysToDue((int) daysToDue);

        if (result.success()) {
            rl.setTwilioSid(result.twilioSid());
            rl.setStatus("SENT");
            remindersSentCounter.increment();
        } else {
            rl.setStatus("FAILED");
            rl.setErrorMessage(result.errorMessage());
            remindersFailedCounter.increment();
            if (result.invalidNumber()) {
                layaway.setContactInvalid(true);
                layawayRepository.save(layaway);
            }
        }
        reminderLogRepository.save(rl);
    }

    /**
     * Compute which reminder type (if any) should be sent today.
     * Public for testability.
     */
    public static ReminderType computeReminderType(Layaway layaway, LocalDate today) {
        long daysToDue = computeDaysToDue(layaway, today);

        if (daysToDue == 3) return ReminderType.T_MINUS_3;
        if (daysToDue == 0) return ReminderType.DUE_TODAY;
        if (daysToDue < 0) {
            long absDays = Math.abs(daysToDue);
            if (absDays > 30) return null; // manual review, no SMS
            if (absDays % 5 == 0) return ReminderType.OVERDUE_EVERY_5;
        }
        return null;
    }

    /**
     * Compute days until due date. Public for testability.
     */
    public static long computeDaysToDue(Layaway layaway, LocalDate today) {
        LocalDate baseDate = layaway.getLastPaymentDate() != null
                ? layaway.getLastPaymentDate()
                : layaway.getCreatedDate();
        LocalDate nextDueDate = baseDate.plusDays(30);
        return ChronoUnit.DAYS.between(today, nextDueDate);
    }

    private String buildMessage(Layaway layaway, ReminderType type, long daysToDue) {
        String name = layaway.getCustomerName();
        String balance = layaway.getBalance().toPlainString();

        return switch (type) {
            case T_MINUS_3 -> String.format(
                    "Hi %s, your layaway payment of $%s is due in 3 days. Reply PAY to make a payment.", name, balance);
            case DUE_TODAY -> String.format(
                    "Hi %s, your layaway payment of $%s is due today! Reply PAY to make a payment.", name, balance);
            case OVERDUE_EVERY_5 -> String.format(
                    "Hi %s, your layaway payment of $%s is %d days overdue. Reply PAY to pay now or CALL to request a callback.",
                    name, balance, Math.abs(daysToDue));
        };
    }
}
EOF

# ── CsvImportService ─────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/service/CsvImportService.java" <<'EOF'
package com.layaway.reminder.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.layaway.reminder.dto.ImportSummaryDto;
import com.layaway.reminder.dto.MappingSuggestionDto;
import com.layaway.reminder.entity.*;
import com.layaway.reminder.enums.ImportJobStatus;
import com.layaway.reminder.enums.LayawayStatus;
import com.layaway.reminder.repository.*;
import com.opencsv.CSVReader;
import com.opencsv.exceptions.CsvValidationException;
import jakarta.persistence.EntityManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStreamReader;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.*;

@Service
public class CsvImportService {

    private static final Logger log = LoggerFactory.getLogger(CsvImportService.class);

    private static final Set<String> REQUIRED_FIELDS = Set.of(
            "external_layaway_id", "customer_name", "phone", "created_date", "balance");
    private static final Set<String> OPTIONAL_FIELDS = Set.of("last_payment_date", "status");
    private static final Set<String> ALL_CANONICAL = new HashSet<>() {{
        addAll(REQUIRED_FIELDS);
        addAll(OPTIONAL_FIELDS);
    }};

    // Synonym map for auto-suggestion
    private static final Map<String, List<String>> SYNONYMS = Map.of(
            "external_layaway_id", List.of("layaway_id", "id", "layaway_number", "account_id", "external_id"),
            "customer_name", List.of("name", "customer", "full_name", "client_name"),
            "phone", List.of("phone_number", "mobile", "cell", "telephone", "contact_phone"),
            "created_date", List.of("create_date", "start_date", "opened_date", "date_created"),
            "last_payment_date", List.of("payment_date", "last_paid", "last_pay_date"),
            "balance", List.of("amount_due", "remaining_balance", "amount_owed", "total_due"),
            "status", List.of("state", "layaway_status", "account_status")
    );

    private final StoreCsvMappingRepository mappingRepository;
    private final LayawayRepository layawayRepository;
    private final ImportJobRepository importJobRepository;
    private final ImportJobErrorRepository importJobErrorRepository;
    private final SyncConflictRepository syncConflictRepository;
    private final PaymentRepository paymentRepository;
    private final EntityManager entityManager;
    private final ObjectMapper objectMapper;

    public CsvImportService(StoreCsvMappingRepository mappingRepository,
                            LayawayRepository layawayRepository,
                            ImportJobRepository importJobRepository,
                            ImportJobErrorRepository importJobErrorRepository,
                            SyncConflictRepository syncConflictRepository,
                            PaymentRepository paymentRepository,
                            EntityManager entityManager,
                            ObjectMapper objectMapper) {
        this.mappingRepository = mappingRepository;
        this.layawayRepository = layawayRepository;
        this.importJobRepository = importJobRepository;
        this.importJobErrorRepository = importJobErrorRepository;
        this.syncConflictRepository = syncConflictRepository;
        this.paymentRepository = paymentRepository;
        this.entityManager = entityManager;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public Object importCsv(Long storeId, MultipartFile file) {
        // Advisory lock per store
        entityManager.createNativeQuery("SELECT pg_advisory_xact_lock(:lockId)")
                .setParameter("lockId", storeId)
                .getSingleResult();

        ImportJob job = new ImportJob();
        job.setStoreId(storeId);
        job.setFilename(file.getOriginalFilename());
        job.setStatus(ImportJobStatus.PROCESSING);
        job.setStartedAt(Instant.now());
        importJobRepository.save(job);

        try (CSVReader reader = new CSVReader(new InputStreamReader(file.getInputStream()))) {
            String[] headers = reader.readNext();
            if (headers == null) {
                job.setStatus(ImportJobStatus.FAILED);
                importJobRepository.save(job);
                return new ImportSummaryDto(job.getId(), 0, 0, 0, List.of("Empty CSV file"));
            }

            // Trim headers
            for (int i = 0; i < headers.length; i++) {
                headers[i] = headers[i].trim().toLowerCase();
            }

            // Get or auto-suggest mapping
            Optional<StoreCsvMapping> mappingOpt = mappingRepository.findByStoreId(storeId);
            Map<String, String> mapping;

            if (mappingOpt.isEmpty()) {
                // Auto-suggest
                Map<String, String> suggestions = suggestMapping(headers);
                return new MappingSuggestionDto(
                        "No CSV mapping configured for this store. Please configure mapping first.",
                        Arrays.asList(headers),
                        suggestions);
            }

            mapping = objectMapper.readValue(mappingOpt.get().getMappingJson(),
                    new TypeReference<Map<String, String>>() {});

            // Validate required fields exist in mapping
            for (String required : REQUIRED_FIELDS) {
                if (!mapping.containsKey(required)) {
                    job.setStatus(ImportJobStatus.FAILED);
                    importJobRepository.save(job);
                    return new ImportSummaryDto(job.getId(), 0, 0, 0,
                            List.of("Missing required field mapping: " + required));
                }
            }

            // Build header index map: canonical_field -> column_index
            Map<String, Integer> fieldIndex = new HashMap<>();
            for (Map.Entry<String, String> entry : mapping.entrySet()) {
                String canonical = entry.getKey();
                String csvHeader = entry.getValue().toLowerCase().trim();
                for (int i = 0; i < headers.length; i++) {
                    if (headers[i].equals(csvHeader)) {
                        fieldIndex.put(canonical, i);
                        break;
                    }
                }
            }

            // Validate all required fields are mapped to actual columns
            for (String required : REQUIRED_FIELDS) {
                if (!fieldIndex.containsKey(required)) {
                    job.setStatus(ImportJobStatus.FAILED);
                    importJobRepository.save(job);
                    return new ImportSummaryDto(job.getId(), 0, 0, 0,
                            List.of("Required field '" + required + "' not found in CSV headers"));
                }
            }

            // Read all rows and deduplicate
            Map<String, String[]> deduplicated = new LinkedHashMap<>();
            List<String[]> allRows = new ArrayList<>();
            String[] row;
            while ((row = reader.readNext()) != null) {
                allRows.add(row);
            }

            for (String[] r : allRows) {
                Integer extIdx = fieldIndex.get("external_layaway_id");
                if (extIdx != null && extIdx < r.length) {
                    deduplicated.put(r[extIdx].trim(), r);
                }
            }

            // Mark all inactive
            layawayRepository.markAllInactiveForStore(storeId);
            entityManager.flush();

            int totalRows = deduplicated.size();
            int successRows = 0;
            int errorRows = 0;
            List<String> errors = new ArrayList<>();
            int rowNum = 0;

            for (Map.Entry<String, String[]> entry : deduplicated.entrySet()) {
                rowNum++;
                String[] data = entry.getValue();
                try {
                    processRow(storeId, job.getId(), data, fieldIndex, rowNum);
                    successRows++;
                } catch (Exception e) {
                    errorRows++;
                    errors.add("Row " + rowNum + ": " + e.getMessage());
                    ImportJobError err = new ImportJobError();
                    err.setImportJobId(job.getId());
                    err.setRowNumber(rowNum);
                    err.setErrorMessage(e.getMessage());
                    err.setRawData(String.join(",", data));
                    importJobErrorRepository.save(err);
                }
            }

            job.setTotalRows(totalRows);
            job.setSuccessRows(successRows);
            job.setErrorRows(errorRows);
            job.setStatus(ImportJobStatus.COMPLETED);
            job.setCompletedAt(Instant.now());
            importJobRepository.save(job);

            return new ImportSummaryDto(job.getId(), totalRows, successRows, errorRows, errors);

        } catch (CsvValidationException | java.io.IOException e) {
            log.error("CSV import error: {}", e.getMessage());
            job.setStatus(ImportJobStatus.FAILED);
            importJobRepository.save(job);
            return new ImportSummaryDto(job.getId(), 0, 0, 0, List.of("CSV parse error: " + e.getMessage()));
        }
    }

    private void processRow(Long storeId, Long jobId, String[] data, Map<String, Integer> fieldIndex, int rowNum) {
        String extId = getField(data, fieldIndex, "external_layaway_id");
        String name = getField(data, fieldIndex, "customer_name");
        String rawPhone = getField(data, fieldIndex, "phone");
        String rawCreatedDate = getField(data, fieldIndex, "created_date");
        String rawBalance = getField(data, fieldIndex, "balance");
        String rawLastPayDate = getFieldOptional(data, fieldIndex, "last_payment_date");
        String rawStatus = getFieldOptional(data, fieldIndex, "status");

        // Validate required
        if (extId == null || extId.isBlank()) throw new IllegalArgumentException("external_layaway_id is required");
        if (name == null || name.isBlank()) throw new IllegalArgumentException("customer_name is required");
        if (rawPhone == null || rawPhone.isBlank()) throw new IllegalArgumentException("phone is required");
        if (rawCreatedDate == null || rawCreatedDate.isBlank()) throw new IllegalArgumentException("created_date is required");
        if (rawBalance == null || rawBalance.isBlank()) throw new IllegalArgumentException("balance is required");

        // Normalize phone
        String phone = PhoneUtils.normalizeToE164(rawPhone);
        if (phone == null) throw new IllegalArgumentException("Invalid phone number: " + rawPhone);

        // Parse date
        LocalDate createdDate;
        try {
            createdDate = LocalDate.parse(rawCreatedDate.trim());
        } catch (DateTimeParseException e) {
            throw new IllegalArgumentException("Invalid created_date format (expected YYYY-MM-DD): " + rawCreatedDate);
        }

        LocalDate lastPayDate = null;
        if (rawLastPayDate != null && !rawLastPayDate.isBlank()) {
            try {
                lastPayDate = LocalDate.parse(rawLastPayDate.trim());
            } catch (DateTimeParseException e) {
                throw new IllegalArgumentException("Invalid last_payment_date format: " + rawLastPayDate);
            }
        }

        // Parse balance
        BigDecimal balance;
        try {
            balance = new BigDecimal(rawBalance.trim().replace("$", "").replace(",", ""));
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Invalid balance: " + rawBalance);
        }
        if (balance.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Balance must be >= 0: " + rawBalance);
        }

        // Parse status
        LayawayStatus status = LayawayStatus.ACTIVE;
        if (rawStatus != null && !rawStatus.isBlank()) {
            try {
                status = LayawayStatus.valueOf(rawStatus.trim().toUpperCase());
            } catch (IllegalArgumentException e) {
                // default to ACTIVE
            }
        }

        // UPSERT
        Optional<Layaway> existingOpt = layawayRepository.findByStoreIdAndExternalLayawayId(storeId, extId.trim());
        Layaway layaway;
        if (existingOpt.isPresent()) {
            layaway = existingOpt.get();

            // CSV conflict strategy: don't erase newer online payment
            if (lastPayDate != null && layaway.getLastPaymentDate() != null
                    && layaway.getLastPaymentDate().isAfter(lastPayDate)) {
                // DB has a newer payment date - keep DB values, log conflict
                SyncConflict conflict = new SyncConflict();
                conflict.setStoreId(storeId);
                conflict.setLayawayId(layaway.getId());
                conflict.setImportJobId(jobId);
                conflict.setField("last_payment_date");
                conflict.setCsvValue(lastPayDate.toString());
                conflict.setDbValue(layaway.getLastPaymentDate().toString());
                conflict.setResolution("KEPT_DB_VALUE");
                syncConflictRepository.save(conflict);
                // Keep DB values for balance and last_payment_date
            } else {
                layaway.setLastPaymentDate(lastPayDate);
                layaway.setBalance(balance);
            }

            layaway.setCustomerName(name.trim());
            layaway.setPhone(phone);
            layaway.setCreatedDate(createdDate);
            layaway.setStatus(status);
        } else {
            layaway = new Layaway();
            layaway.setStoreId(storeId);
            layaway.setExternalLayawayId(extId.trim());
            layaway.setCustomerName(name.trim());
            layaway.setPhone(phone);
            layaway.setCreatedDate(createdDate);
            layaway.setLastPaymentDate(lastPayDate);
            layaway.setBalance(balance);
            layaway.setStatus(status);
        }

        layaway.setInactive(false);
        layaway.setUpdatedAt(Instant.now());
        layawayRepository.save(layaway);
    }

    private String getField(String[] data, Map<String, Integer> fieldIndex, String field) {
        Integer idx = fieldIndex.get(field);
        if (idx == null || idx >= data.length) return null;
        return data[idx].trim();
    }

    private String getFieldOptional(String[] data, Map<String, Integer> fieldIndex, String field) {
        Integer idx = fieldIndex.get(field);
        if (idx == null || idx >= data.length) return null;
        String val = data[idx].trim();
        return val.isEmpty() ? null : val;
    }

    /** Generate auto-suggestions for CSV header -> canonical field mapping. */
    public Map<String, String> suggestMapping(String[] headers) {
        Map<String, String> suggestions = new LinkedHashMap<>();
        for (String header : headers) {
            String lower = header.toLowerCase().trim();
            for (Map.Entry<String, List<String>> entry : SYNONYMS.entrySet()) {
                String canonical = entry.getKey();
                if (lower.equals(canonical) || entry.getValue().contains(lower)) {
                    suggestions.put(canonical, header);
                    break;
                }
            }
        }
        return suggestions;
    }
}
EOF

# ── PaymentService ───────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/service/PaymentService.java" <<'EOF'
package com.layaway.reminder.service;

import com.layaway.reminder.config.AppProperties;
import com.layaway.reminder.config.StripeProperties;
import com.layaway.reminder.dto.CheckoutRequestDto;
import com.layaway.reminder.dto.PaymentPageDto;
import com.layaway.reminder.entity.*;
import com.layaway.reminder.enums.LayawayStatus;
import com.layaway.reminder.repository.*;
import com.stripe.exception.StripeException;
import com.stripe.model.checkout.Session;
import com.stripe.param.checkout.SessionCreateParams;
import io.micrometer.core.instrument.Counter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.UUID;

@Service
public class PaymentService {

    private static final Logger log = LoggerFactory.getLogger(PaymentService.class);
    private static final BigDecimal MIN_AMOUNT = new BigDecimal("20.00");

    private final PaymentSessionRepository paymentSessionRepository;
    private final PaymentRepository paymentRepository;
    private final LayawayRepository layawayRepository;
    private final StripeEventRepository stripeEventRepository;
    private final TwilioService twilioService;
    private final AppProperties appProperties;
    private final StripeProperties stripeProperties;
    private final Counter paymentsCompletedCounter;

    public PaymentService(PaymentSessionRepository paymentSessionRepository,
                          PaymentRepository paymentRepository,
                          LayawayRepository layawayRepository,
                          StripeEventRepository stripeEventRepository,
                          TwilioService twilioService,
                          AppProperties appProperties,
                          StripeProperties stripeProperties,
                          @Qualifier("paymentsCompletedCounter") Counter paymentsCompletedCounter) {
        this.paymentSessionRepository = paymentSessionRepository;
        this.paymentRepository = paymentRepository;
        this.layawayRepository = layawayRepository;
        this.stripeEventRepository = stripeEventRepository;
        this.twilioService = twilioService;
        this.appProperties = appProperties;
        this.stripeProperties = stripeProperties;
        this.paymentsCompletedCounter = paymentsCompletedCounter;
    }

    /** Create a payment session for a layaway. Returns the pay link token. */
    @Transactional
    public String createPaymentSession(Long storeId, Long layawayId) {
        Layaway layaway = layawayRepository.findById(layawayId)
                .orElseThrow(() -> new IllegalArgumentException("Layaway not found"));

        BigDecimal balance = layaway.getBalance();
        BigDecimal min = balance.compareTo(MIN_AMOUNT) < 0 ? balance : MIN_AMOUNT;
        BigDecimal max = balance;

        String token = UUID.randomUUID().toString();
        PaymentSession ps = new PaymentSession();
        ps.setStoreId(storeId);
        ps.setLayawayId(layawayId);
        ps.setToken(token);
        ps.setAmountMin(min);
        ps.setAmountMax(max);
        ps.setExpiresAt(Instant.now().plus(24, ChronoUnit.HOURS));
        paymentSessionRepository.save(ps);

        return token;
    }

    /** Validate token and return payment page data. */
    public PaymentPageDto getPaymentPage(String token) {
        PaymentSession ps = paymentSessionRepository.findByToken(token)
                .orElseThrow(() -> new IllegalArgumentException("Invalid payment link"));

        if (ps.getUsed()) throw new IllegalStateException("Payment link already used");
        if (ps.getExpiresAt().isBefore(Instant.now())) throw new IllegalStateException("Payment link expired");

        Layaway layaway = layawayRepository.findById(ps.getLayawayId())
                .orElseThrow(() -> new IllegalStateException("Layaway not found"));

        BigDecimal balance = layaway.getBalance();
        BigDecimal min = balance.compareTo(MIN_AMOUNT) < 0 ? balance : MIN_AMOUNT;

        return new PaymentPageDto(
                layaway.getCustomerName(),
                layaway.getExternalLayawayId(),
                balance,
                min,
                balance,
                token
        );
    }

    /** Create Stripe Checkout Session. */
    @Transactional
    public String createCheckoutSession(String token, CheckoutRequestDto request) throws StripeException {
        PaymentSession ps = paymentSessionRepository.findByToken(token)
                .orElseThrow(() -> new IllegalArgumentException("Invalid payment link"));

        if (ps.getUsed()) throw new IllegalStateException("Payment link already used");
        if (ps.getExpiresAt().isBefore(Instant.now())) throw new IllegalStateException("Payment link expired");

        Layaway layaway = layawayRepository.findById(ps.getLayawayId())
                .orElseThrow(() -> new IllegalStateException("Layaway not found"));

        BigDecimal amount = request.amount();
        BigDecimal balance = layaway.getBalance();
        BigDecimal min = balance.compareTo(MIN_AMOUNT) < 0 ? balance : MIN_AMOUNT;

        if (amount.compareTo(min) < 0 || amount.compareTo(balance) > 0) {
            throw new IllegalArgumentException(
                    String.format("Amount must be between $%s and $%s", min.toPlainString(), balance.toPlainString()));
        }

        long amountInCents = amount.multiply(new BigDecimal("100")).longValue();

        SessionCreateParams params = SessionCreateParams.builder()
                .setMode(SessionCreateParams.Mode.PAYMENT)
                .setSuccessUrl(appProperties.getBaseUrl() + "/pay/" + token + "?status=success")
                .setCancelUrl(appProperties.getBaseUrl() + "/pay/" + token + "?status=cancel")
                .addLineItem(SessionCreateParams.LineItem.builder()
                        .setQuantity(1L)
                        .setPriceData(SessionCreateParams.LineItem.PriceData.builder()
                                .setCurrency("usd")
                                .setUnitAmount(amountInCents)
                                .setProductData(SessionCreateParams.LineItem.PriceData.ProductData.builder()
                                        .setName("Layaway Payment - " + layaway.getExternalLayawayId())
                                        .build())
                                .build())
                        .build())
                .putMetadata("store_id", ps.getStoreId().toString())
                .putMetadata("layaway_id", ps.getLayawayId().toString())
                .putMetadata("token", token)
                .build();

        Session session = Session.create(params);
        return session.getUrl();
    }

    /** Handle Stripe checkout.session.completed webhook (idempotent). */
    @Transactional
    public boolean handleCheckoutCompleted(String stripeEventId, String checkoutSessionId,
                                           Long amountTotal, Map<String, String> metadata) {
        // Idempotency check
        if (stripeEventRepository.existsByStripeEventId(stripeEventId)) {
            log.info("Stripe event {} already processed, skipping", stripeEventId);
            return false;
        }

        // Record event
        StripeEvent se = new StripeEvent();
        se.setStripeEventId(stripeEventId);
        se.setEventType("checkout.session.completed");
        se.setProcessed(true);
        stripeEventRepository.save(se);

        String token = metadata.get("token");
        Long layawayId = Long.parseLong(metadata.get("layaway_id"));
        Long storeId = Long.parseLong(metadata.get("store_id"));

        BigDecimal amount = new BigDecimal(amountTotal).divide(new BigDecimal("100"));

        // Mark session used
        paymentSessionRepository.findByToken(token).ifPresent(ps -> {
            ps.setUsed(true);
            paymentSessionRepository.save(ps);
        });

        // Record payment
        Payment payment = new Payment();
        payment.setStoreId(storeId);
        payment.setLayawayId(layawayId);
        payment.setAmount(amount);
        payment.setStripeCheckoutSessionId(checkoutSessionId);
        paymentSessionRepository.findByToken(token).ifPresent(ps -> payment.setPaymentSessionId(ps.getId()));
        paymentRepository.save(payment);

        // Update layaway
        layawayRepository.findById(layawayId).ifPresent(layaway -> {
            BigDecimal newBalance = layaway.getBalance().subtract(amount);
            if (newBalance.compareTo(BigDecimal.ZERO) < 0) newBalance = BigDecimal.ZERO;
            layaway.setBalance(newBalance);
            layaway.setLastPaymentDate(LocalDate.now());
            if (newBalance.compareTo(BigDecimal.ZERO) == 0) {
                layaway.setStatus(LayawayStatus.PAID);
            }
            layaway.setUpdatedAt(Instant.now());
            layawayRepository.save(layaway);

            // Send receipt SMS
            String receiptMsg = String.format(
                    "Payment of $%s received for layaway %s. Remaining balance: $%s. Thank you!",
                    amount.toPlainString(), layaway.getExternalLayawayId(), newBalance.toPlainString());
            twilioService.sendSms(storeId, layawayId, layaway.getPhone(), receiptMsg);
        });

        paymentsCompletedCounter.increment();
        return true;
    }

    /**
     * Validate payment amount rules. Public for testing.
     */
    public static BigDecimal computeMinAmount(BigDecimal balance) {
        if (balance.compareTo(MIN_AMOUNT) < 0) return balance;
        return MIN_AMOUNT;
    }

    public static boolean isAmountValid(BigDecimal amount, BigDecimal balance) {
        BigDecimal min = computeMinAmount(balance);
        return amount.compareTo(min) >= 0 && amount.compareTo(balance) <= 0;
    }
}
EOF

# ── InboundSmsService ────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/service/InboundSmsService.java" <<'EOF'
package com.layaway.reminder.service;

import com.layaway.reminder.config.AppProperties;
import com.layaway.reminder.entity.*;
import com.layaway.reminder.enums.LayawayStatus;
import com.layaway.reminder.repository.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class InboundSmsService {

    private static final Logger log = LoggerFactory.getLogger(InboundSmsService.class);

    private final InboundMessageLogRepository inboundLogRepository;
    private final OutboundMessageRepository outboundMessageRepository;
    private final LayawayRepository layawayRepository;
    private final CallTaskRepository callTaskRepository;
    private final PaymentService paymentService;
    private final TwilioService twilioService;
    private final AppProperties appProperties;

    public InboundSmsService(InboundMessageLogRepository inboundLogRepository,
                             OutboundMessageRepository outboundMessageRepository,
                             LayawayRepository layawayRepository,
                             CallTaskRepository callTaskRepository,
                             PaymentService paymentService,
                             TwilioService twilioService,
                             AppProperties appProperties) {
        this.inboundLogRepository = inboundLogRepository;
        this.outboundMessageRepository = outboundMessageRepository;
        this.layawayRepository = layawayRepository;
        this.callTaskRepository = callTaskRepository;
        this.paymentService = paymentService;
        this.twilioService = twilioService;
        this.appProperties = appProperties;
    }

    @Transactional
    public String processInbound(String from, String to, String body, String messageSid) {
        InboundMessageLog logEntry = new InboundMessageLog();
        logEntry.setFromPhone(from);
        logEntry.setToPhone(to);
        logEntry.setBody(body);
        logEntry.setTwilioMessageSid(messageSid);

        String command = body != null ? body.trim().toUpperCase() : "";
        logEntry.setCommand(command);

        // Resolve layaway from phone
        Layaway layaway = resolveLayaway(from);
        if (layaway != null) {
            logEntry.setLayawayId(layaway.getId());
        }

        logEntry.setProcessed(true);
        inboundLogRepository.save(logEntry);

        if (layaway == null) {
            // Try to find any active layaways for disambiguation
            List<Layaway> candidates = layawayRepository.findByPhoneAndInactiveFalseAndStatus(from, LayawayStatus.ACTIVE);
            if (candidates.isEmpty()) {
                return "We could not find an active layaway associated with this number.";
            } else if (candidates.size() > 1) {
                StringBuilder sb = new StringBuilder("Multiple layaways found. Reply with the number:\n");
                for (int i = 0; i < candidates.size(); i++) {
                    sb.append(i + 1).append(") ").append(candidates.get(i).getExternalLayawayId()).append("\n");
                }
                return sb.toString();
            }
            layaway = candidates.get(0);
        }

        return switch (command) {
            case "PAY" -> handlePay(layaway);
            case "CALL" -> handleCall(layaway);
            case "STOP" -> handleStop(layaway);
            case "START" -> handleStart(layaway);
            default -> "Commands: PAY, CALL, STOP, START";
        };
    }

    private Layaway resolveLayaway(String phone) {
        Instant since = Instant.now().minus(30, ChronoUnit.DAYS);
        List<OutboundMessage> recent = outboundMessageRepository.findRecentByPhone(phone, since);
        if (recent.isEmpty()) return null;

        OutboundMessage mostRecent = recent.get(0);
        if (mostRecent.getLayawayId() != null) {
            return layawayRepository.findById(mostRecent.getLayawayId()).orElse(null);
        }
        return null;
    }

    private String handlePay(Layaway layaway) {
        String token = paymentService.createPaymentSession(layaway.getStoreId(), layaway.getId());
        String payLink = appProperties.getBaseUrl() + "/pay/" + token;
        return String.format("Pay your layaway here: %s\nOr call the store at your convenience.", payLink);
    }

    private String handleCall(Layaway layaway) {
        CallTask task = new CallTask();
        task.setStoreId(layaway.getStoreId());
        task.setLayawayId(layaway.getId());
        task.setCustomerName(layaway.getCustomerName());
        task.setPhone(layaway.getPhone());
        task.setReason("Customer requested callback via SMS");
        callTaskRepository.save(task);
        return "We've noted your request. A store associate will call you back soon.";
    }

    private String handleStop(Layaway layaway) {
        layaway.setReminderPaused(true);
        layawayRepository.save(layaway);
        return "Reminders paused for your layaway. Reply START to resume.";
    }

    private String handleStart(Layaway layaway) {
        layaway.setReminderPaused(false);
        layawayRepository.save(layaway);
        return "Reminders resumed for your layaway.";
    }
}
EOF

# ── AdminController ──────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/controller/AdminController.java" <<'EOF'
package com.layaway.reminder.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.layaway.reminder.dto.CsvMappingDto;
import com.layaway.reminder.entity.*;
import com.layaway.reminder.repository.*;
import com.layaway.reminder.service.CsvImportService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private final StoreCsvMappingRepository mappingRepository;
    private final CsvImportService csvImportService;
    private final ImportJobRepository importJobRepository;
    private final LayawayRepository layawayRepository;
    private final ReminderLogRepository reminderLogRepository;
    private final CallTaskRepository callTaskRepository;
    private final ObjectMapper objectMapper;

    public AdminController(StoreCsvMappingRepository mappingRepository,
                           CsvImportService csvImportService,
                           ImportJobRepository importJobRepository,
                           LayawayRepository layawayRepository,
                           ReminderLogRepository reminderLogRepository,
                           CallTaskRepository callTaskRepository,
                           ObjectMapper objectMapper) {
        this.mappingRepository = mappingRepository;
        this.csvImportService = csvImportService;
        this.importJobRepository = importJobRepository;
        this.layawayRepository = layawayRepository;
        this.reminderLogRepository = reminderLogRepository;
        this.callTaskRepository = callTaskRepository;
        this.objectMapper = objectMapper;
    }

    @GetMapping("/stores/{storeId}/csv-mapping")
    public ResponseEntity<?> getCsvMapping(@PathVariable Long storeId) {
        return mappingRepository.findByStoreId(storeId)
                .map(m -> ResponseEntity.ok(Map.of("storeId", storeId, "mapping", m.getMappingJson())))
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/stores/{storeId}/csv-mapping")
    public ResponseEntity<?> putCsvMapping(@PathVariable Long storeId, @RequestBody CsvMappingDto dto) {
        try {
            String json = objectMapper.writeValueAsString(dto.mapping());
            StoreCsvMapping mapping = mappingRepository.findByStoreId(storeId).orElse(new StoreCsvMapping());
            mapping.setStoreId(storeId);
            mapping.setMappingJson(json);
            mapping.setUpdatedAt(Instant.now());
            mappingRepository.save(mapping);
            return ResponseEntity.ok(Map.of("storeId", storeId, "mapping", json));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/stores/{storeId}/imports/csv")
    public ResponseEntity<?> importCsv(@PathVariable Long storeId, @RequestParam("file") MultipartFile file) {
        Object result = csvImportService.importCsv(storeId, file);
        if (result instanceof com.layaway.reminder.dto.MappingSuggestionDto) {
            return ResponseEntity.badRequest().body(result);
        }
        return ResponseEntity.ok(result);
    }

    @GetMapping("/imports/{jobId}")
    public ResponseEntity<?> getImportJob(@PathVariable Long jobId) {
        return importJobRepository.findById(jobId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/layaways/manual-review")
    public ResponseEntity<List<Layaway>> listManualReview() {
        return ResponseEntity.ok(layawayRepository.findByNeedsManualReviewTrue());
    }

    @GetMapping("/reminders/today")
    public ResponseEntity<List<ReminderLog>> listTodayReminders() {
        return ResponseEntity.ok(reminderLogRepository.findByReminderDate(LocalDate.now()));
    }

    @GetMapping("/call-tasks")
    public ResponseEntity<List<CallTask>> listCallTasks() {
        return ResponseEntity.ok(callTaskRepository.findByResolvedFalse());
    }
}
EOF

# ── TwilioWebhookController ─────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/controller/TwilioWebhookController.java" <<'EOF'
package com.layaway.reminder.controller;

import com.layaway.reminder.config.TwilioProperties;
import com.layaway.reminder.service.InboundSmsService;
import com.twilio.security.RequestValidator;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/webhooks/twilio")
public class TwilioWebhookController {

    private static final Logger log = LoggerFactory.getLogger(TwilioWebhookController.class);

    private final InboundSmsService inboundSmsService;
    private final TwilioProperties twilioProperties;

    public TwilioWebhookController(InboundSmsService inboundSmsService,
                                   TwilioProperties twilioProperties) {
        this.inboundSmsService = inboundSmsService;
        this.twilioProperties = twilioProperties;
    }

    @PostMapping(value = "/sms", consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE)
    public ResponseEntity<String> handleInboundSms(
            @RequestParam Map<String, String> params,
            HttpServletRequest request) {

        // Verify Twilio signature
        if (!verifyTwilioSignature(request, params)) {
            log.warn("Invalid Twilio signature");
            return ResponseEntity.status(403).body("<Response><Message>Forbidden</Message></Response>");
        }

        String from = params.get("From");
        String to = params.get("To");
        String body = params.get("Body");
        String messageSid = params.get("MessageSid");

        log.info("Inbound SMS from {} body: {}", from, body);

        String reply = inboundSmsService.processInbound(from, to, body, messageSid);

        // Return TwiML response
        String twiml = "<Response><Message>" + escapeXml(reply) + "</Message></Response>";
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_XML)
                .body(twiml);
    }

    private boolean verifyTwilioSignature(HttpServletRequest request, Map<String, String> params) {
        String authToken = twilioProperties.getAuthToken();
        if (authToken == null || authToken.isBlank()) {
            log.warn("Twilio auth token not configured, skipping signature verification");
            return true;
        }

        String signature = request.getHeader("X-Twilio-Signature");
        if (signature == null) return false;

        String url = request.getRequestURL().toString();

        // If behind a proxy, use X-Forwarded-Proto
        String proto = request.getHeader("X-Forwarded-Proto");
        if (proto != null) {
            url = url.replaceFirst("^http:", proto + ":");
        }

        RequestValidator validator = new RequestValidator(authToken);
        return validator.validate(url, params, signature);
    }

    private String escapeXml(String input) {
        if (input == null) return "";
        return input.replace("&", "&amp;")
                    .replace("<", "&lt;")
                    .replace(">", "&gt;")
                    .replace("\"", "&quot;")
                    .replace("'", "&apos;");
    }
}
EOF

# ── StripeWebhookController ─────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/controller/StripeWebhookController.java" <<'EOF'
package com.layaway.reminder.controller;

import com.layaway.reminder.config.StripeProperties;
import com.layaway.reminder.service.PaymentService;
import com.stripe.exception.SignatureVerificationException;
import com.stripe.model.Event;
import com.stripe.model.checkout.Session;
import com.stripe.net.Webhook;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/webhooks/stripe")
public class StripeWebhookController {

    private static final Logger log = LoggerFactory.getLogger(StripeWebhookController.class);

    private final PaymentService paymentService;
    private final StripeProperties stripeProperties;

    public StripeWebhookController(PaymentService paymentService, StripeProperties stripeProperties) {
        this.paymentService = paymentService;
        this.stripeProperties = stripeProperties;
    }

    @PostMapping
    public ResponseEntity<String> handleWebhook(
            @RequestBody String payload,
            @RequestHeader("Stripe-Signature") String sigHeader) {

        Event event;
        try {
            event = Webhook.constructEvent(payload, sigHeader, stripeProperties.getWebhookSecret());
        } catch (SignatureVerificationException e) {
            log.warn("Invalid Stripe signature: {}", e.getMessage());
            return ResponseEntity.status(400).body("Invalid signature");
        }

        if ("checkout.session.completed".equals(event.getType())) {
            Session session = (Session) event.getDataObjectDeserializer()
                    .getObject().orElse(null);

            if (session != null) {
                Map<String, String> metadata = session.getMetadata();
                paymentService.handleCheckoutCompleted(
                        event.getId(),
                        session.getId(),
                        session.getAmountTotal(),
                        metadata);
            }
        }

        return ResponseEntity.ok("ok");
    }
}
EOF

# ── PaymentController ────────────────────────────────────────────────
cat > "$PROJECT/src/main/java/$BASE_PKG/controller/PaymentController.java" <<'EOF'
package com.layaway.reminder.controller;

import com.layaway.reminder.dto.CheckoutRequestDto;
import com.layaway.reminder.dto.PaymentPageDto;
import com.layaway.reminder.service.PaymentService;
import com.stripe.exception.StripeException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/pay")
public class PaymentController {

    private final PaymentService paymentService;

    public PaymentController(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    @GetMapping("/{token}")
    public ResponseEntity<?> getPaymentPage(@PathVariable String token) {
        try {
            PaymentPageDto dto = paymentService.getPaymentPage(token);
            return ResponseEntity.ok(dto);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/{token}/checkout")
    public ResponseEntity<?> checkout(@PathVariable String token, @RequestBody CheckoutRequestDto request) {
        try {
            String checkoutUrl = paymentService.createCheckoutSession(token, request);
            return ResponseEntity.ok(Map.of("checkoutUrl", checkoutUrl));
        } catch (StripeException e) {
            return ResponseEntity.internalServerError().body(Map.of("error", "Payment processing error"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
EOF

# ── Test: ReminderRulesTest ───────────────────────────────────────────
cat > "$PROJECT/src/test/java/$BASE_PKG/ReminderRulesTest.java" <<'EOF'
package com.layaway.reminder;

import com.layaway.reminder.entity.Layaway;
import com.layaway.reminder.enums.LayawayStatus;
import com.layaway.reminder.enums.ReminderType;
import com.layaway.reminder.service.ReminderService;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.*;

class ReminderRulesTest {

    private Layaway buildLayaway(LocalDate createdDate, LocalDate lastPayDate) {
        Layaway l = new Layaway();
        l.setCreatedDate(createdDate);
        l.setLastPaymentDate(lastPayDate);
        l.setBalance(new BigDecimal("100.00"));
        l.setStatus(LayawayStatus.ACTIVE);
        l.setInactive(false);
        l.setReminderPaused(false);
        l.setNeedsManualReview(false);
        l.setContactInvalid(false);
        return l;
    }

    @Test
    void testTMinus3() {
        LocalDate created = LocalDate.of(2024, 1, 1);
        // nextDue = created + 30 = Jan 31
        // daysToDue = 3 => today = Jan 28
        LocalDate today = LocalDate.of(2024, 1, 28);
        Layaway l = buildLayaway(created, null);
        assertEquals(ReminderType.T_MINUS_3, ReminderService.computeReminderType(l, today));
    }

    @Test
    void testDueToday() {
        LocalDate created = LocalDate.of(2024, 1, 1);
        // nextDue = Jan 31, daysToDue = 0 => today = Jan 31
        LocalDate today = LocalDate.of(2024, 1, 31);
        Layaway l = buildLayaway(created, null);
        assertEquals(ReminderType.DUE_TODAY, ReminderService.computeReminderType(l, today));
    }

    @Test
    void testOverdueEvery5() {
        LocalDate created = LocalDate.of(2024, 1, 1);
        // nextDue = Jan 31
        // daysToDue = -5 => today = Feb 5
        LocalDate today = LocalDate.of(2024, 2, 5);
        Layaway l = buildLayaway(created, null);
        assertEquals(ReminderType.OVERDUE_EVERY_5, ReminderService.computeReminderType(l, today));
    }

    @Test
    void testOverdue10Days() {
        LocalDate created = LocalDate.of(2024, 1, 1);
        // nextDue = Jan 31
        // daysToDue = -10 => today = Feb 10
        LocalDate today = LocalDate.of(2024, 2, 10);
        Layaway l = buildLayaway(created, null);
        assertEquals(ReminderType.OVERDUE_EVERY_5, ReminderService.computeReminderType(l, today));
    }

    @Test
    void testOverdue3DaysNoReminder() {
        LocalDate created = LocalDate.of(2024, 1, 1);
        // daysToDue = -3 => today = Feb 3
        LocalDate today = LocalDate.of(2024, 2, 3);
        Layaway l = buildLayaway(created, null);
        assertNull(ReminderService.computeReminderType(l, today));
    }

    @Test
    void testOverdueMoreThan30DaysNull() {
        LocalDate created = LocalDate.of(2024, 1, 1);
        // nextDue = Jan 31
        // daysToDue = -31 => today = Mar 2
        LocalDate today = LocalDate.of(2024, 3, 2);
        Layaway l = buildLayaway(created, null);
        assertNull(ReminderService.computeReminderType(l, today));
    }

    @Test
    void testUsesLastPaymentDateIfPresent() {
        LocalDate created = LocalDate.of(2024, 1, 1);
        LocalDate lastPay = LocalDate.of(2024, 2, 1);
        // baseDate = lastPay = Feb 1, nextDue = Mar 2
        // daysToDue = 3 => today = Feb 28
        LocalDate today = LocalDate.of(2024, 2, 28);
        Layaway l = buildLayaway(created, lastPay);
        assertEquals(ReminderType.T_MINUS_3, ReminderService.computeReminderType(l, today));
    }

    @Test
    void testDaysToDueComputation() {
        LocalDate created = LocalDate.of(2024, 1, 1);
        Layaway l = buildLayaway(created, null);
        // nextDue = Jan 31, today = Jan 28 => daysToDue = 3
        assertEquals(3, ReminderService.computeDaysToDue(l, LocalDate.of(2024, 1, 28)));
        // today = Jan 31 => daysToDue = 0
        assertEquals(0, ReminderService.computeDaysToDue(l, LocalDate.of(2024, 1, 31)));
        // today = Feb 5 => daysToDue = -5
        assertEquals(-5, ReminderService.computeDaysToDue(l, LocalDate.of(2024, 2, 5)));
    }

    @Test
    void testNotDueYet() {
        LocalDate created = LocalDate.of(2024, 1, 1);
        LocalDate today = LocalDate.of(2024, 1, 10); // daysToDue = 21
        Layaway l = buildLayaway(created, null);
        assertNull(ReminderService.computeReminderType(l, today));
    }

    @Test
    void testOverdue30ExactDay() {
        LocalDate created = LocalDate.of(2024, 1, 1);
        // nextDue = Jan 31, daysToDue = -30 => today = Mar 1
        LocalDate today = LocalDate.of(2024, 3, 1);
        Layaway l = buildLayaway(created, null);
        // abs(daysToDue) = 30, 30%5 == 0, 30 <= 30 => OVERDUE_EVERY_5
        assertEquals(ReminderType.OVERDUE_EVERY_5, ReminderService.computeReminderType(l, today));
    }
}
EOF

# ── Test: AmountRulesTest ────────────────────────────────────────────
cat > "$PROJECT/src/test/java/$BASE_PKG/AmountRulesTest.java" <<'EOF'
package com.layaway.reminder;

import com.layaway.reminder.service.PaymentService;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

class AmountRulesTest {

    @Test
    void testMinAmountWhenBalanceAbove20() {
        BigDecimal balance = new BigDecimal("100.00");
        assertEquals(new BigDecimal("20.00"), PaymentService.computeMinAmount(balance));
    }

    @Test
    void testMinAmountWhenBalanceBelow20() {
        BigDecimal balance = new BigDecimal("15.00");
        assertEquals(new BigDecimal("15.00"), PaymentService.computeMinAmount(balance));
    }

    @Test
    void testMinAmountWhenBalanceExact20() {
        BigDecimal balance = new BigDecimal("20.00");
        assertEquals(new BigDecimal("20.00"), PaymentService.computeMinAmount(balance));
    }

    @Test
    void testValidAmount() {
        BigDecimal balance = new BigDecimal("100.00");
        assertTrue(PaymentService.isAmountValid(new BigDecimal("20.00"), balance));
        assertTrue(PaymentService.isAmountValid(new BigDecimal("50.00"), balance));
        assertTrue(PaymentService.isAmountValid(new BigDecimal("100.00"), balance));
    }

    @Test
    void testInvalidAmountTooLow() {
        BigDecimal balance = new BigDecimal("100.00");
        assertFalse(PaymentService.isAmountValid(new BigDecimal("19.99"), balance));
    }

    @Test
    void testInvalidAmountTooHigh() {
        BigDecimal balance = new BigDecimal("100.00");
        assertFalse(PaymentService.isAmountValid(new BigDecimal("100.01"), balance));
    }

    @Test
    void testSmallBalanceForceFullPayment() {
        BigDecimal balance = new BigDecimal("15.00");
        assertTrue(PaymentService.isAmountValid(new BigDecimal("15.00"), balance));
        assertFalse(PaymentService.isAmountValid(new BigDecimal("10.00"), balance));
    }
}
EOF

# ── Test: CsvParsingTest ────────────────────────────────────────────
cat > "$PROJECT/src/test/java/$BASE_PKG/CsvParsingTest.java" <<'EOF'
package com.layaway.reminder;

import com.layaway.reminder.service.CsvImportService;
import com.layaway.reminder.service.PhoneUtils;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class CsvParsingTest {

    @Test
    void testPhoneNormalization10Digit() {
        assertEquals("+12125551234", PhoneUtils.normalizeToE164("2125551234"));
    }

    @Test
    void testPhoneNormalization11Digit() {
        assertEquals("+12125551234", PhoneUtils.normalizeToE164("12125551234"));
    }

    @Test
    void testPhoneNormalizationFormatted() {
        assertEquals("+12125551234", PhoneUtils.normalizeToE164("(212) 555-1234"));
    }

    @Test
    void testPhoneNormalizationWithDashes() {
        assertEquals("+12125551234", PhoneUtils.normalizeToE164("212-555-1234"));
    }

    @Test
    void testPhoneNormalizationInvalid() {
        assertNull(PhoneUtils.normalizeToE164("12345"));
    }

    @Test
    void testPhoneNormalizationNull() {
        assertNull(PhoneUtils.normalizeToE164(null));
    }

    @Test
    void testPhoneNormalizationAlreadyE164() {
        assertEquals("+12125551234", PhoneUtils.normalizeToE164("+12125551234"));
    }

    @Test
    void testSuggestMapping() {
        CsvImportService service = new CsvImportService(null, null, null, null, null, null, null, null);
        String[] headers = {"Layaway ID", "Name", "Phone Number", "Start Date", "Amount Due", "Last Paid"};
        Map<String, String> suggestions = service.suggestMapping(
                new String[]{"layaway_id", "name", "phone_number", "start_date", "amount_due", "last_paid"});
        assertTrue(suggestions.containsKey("external_layaway_id"));
        assertTrue(suggestions.containsKey("customer_name"));
        assertTrue(suggestions.containsKey("phone"));
        assertTrue(suggestions.containsKey("balance"));
    }
}
EOF

# ── Test: StripeWebhookIdempotencyTest ───────────────────────────────
cat > "$PROJECT/src/test/java/$BASE_PKG/StripeWebhookIdempotencyTest.java" <<'EOF'
package com.layaway.reminder;

import com.layaway.reminder.entity.*;
import com.layaway.reminder.enums.LayawayStatus;
import com.layaway.reminder.repository.*;
import com.layaway.reminder.service.PaymentService;
import com.layaway.reminder.service.TwilioService;
import com.layaway.reminder.config.AppProperties;
import com.layaway.reminder.config.StripeProperties;
import io.micrometer.core.instrument.Counter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@SpringBootTest
@ActiveProfiles("test")
class StripeWebhookIdempotencyTest {

    @Autowired
    private PaymentService paymentService;

    @Autowired
    private StripeEventRepository stripeEventRepository;

    @Autowired
    private LayawayRepository layawayRepository;

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private PaymentSessionRepository paymentSessionRepository;

    @Autowired
    private StoreRepository storeRepository;

    @MockBean
    private TwilioService twilioService;

    private Layaway testLayaway;
    private PaymentSession testSession;

    @BeforeEach
    void setup() {
        paymentRepository.deleteAll();
        paymentSessionRepository.deleteAll();
        stripeEventRepository.deleteAll();
        layawayRepository.deleteAll();
        storeRepository.deleteAll();

        Store store = new Store();
        store.setName("Test Store");
        store = storeRepository.save(store);

        testLayaway = new Layaway();
        testLayaway.setStoreId(store.getId());
        testLayaway.setExternalLayawayId("LAY-001");
        testLayaway.setCustomerName("John Doe");
        testLayaway.setPhone("+15551234567");
        testLayaway.setCreatedDate(LocalDate.now().minusDays(30));
        testLayaway.setBalance(new BigDecimal("200.00"));
        testLayaway.setStatus(LayawayStatus.ACTIVE);
        testLayaway = layawayRepository.save(testLayaway);

        testSession = new PaymentSession();
        testSession.setStoreId(store.getId());
        testSession.setLayawayId(testLayaway.getId());
        testSession.setToken("test-token-123");
        testSession.setAmountMin(new BigDecimal("20.00"));
        testSession.setAmountMax(new BigDecimal("200.00"));
        testSession.setExpiresAt(Instant.now().plus(24, ChronoUnit.HOURS));
        testSession = paymentSessionRepository.save(testSession);

        when(twilioService.sendSms(any(), any(), any(), any()))
                .thenReturn(new TwilioService.SendResult(true, "SM123", null, false));
    }

    @Test
    void testFirstEventProcessed() {
        Map<String, String> metadata = Map.of(
                "store_id", testLayaway.getStoreId().toString(),
                "layaway_id", testLayaway.getId().toString(),
                "token", "test-token-123"
        );

        boolean result = paymentService.handleCheckoutCompleted(
                "evt_test_001", "cs_test_001", 5000L, metadata);

        assertTrue(result);
        assertEquals(1, stripeEventRepository.count());

        Layaway updated = layawayRepository.findById(testLayaway.getId()).orElseThrow();
        assertEquals(new BigDecimal("150.00"), updated.getBalance());
    }

    @Test
    void testDuplicateEventSkipped() {
        Map<String, String> metadata = Map.of(
                "store_id", testLayaway.getStoreId().toString(),
                "layaway_id", testLayaway.getId().toString(),
                "token", "test-token-123"
        );

        // First call
        paymentService.handleCheckoutCompleted("evt_test_002", "cs_test_002", 5000L, metadata);

        // Second call with same event ID
        boolean result = paymentService.handleCheckoutCompleted("evt_test_002", "cs_test_002", 5000L, metadata);

        assertFalse(result);
        // Balance should only be reduced once
        Layaway updated = layawayRepository.findById(testLayaway.getId()).orElseThrow();
        assertEquals(new BigDecimal("150.00"), updated.getBalance());
    }

    @Test
    void testFullPaymentSetsPaidStatus() {
        Map<String, String> metadata = Map.of(
                "store_id", testLayaway.getStoreId().toString(),
                "layaway_id", testLayaway.getId().toString(),
                "token", "test-token-123"
        );

        paymentService.handleCheckoutCompleted("evt_test_003", "cs_test_003", 20000L, metadata);

        Layaway updated = layawayRepository.findById(testLayaway.getId()).orElseThrow();
        assertEquals(BigDecimal.ZERO.setScale(2), updated.getBalance().setScale(2));
        assertEquals(LayawayStatus.PAID, updated.getStatus());
    }
}
EOF

# ── Sample CSV ───────────────────────────────────────────────────────
cat > "$PROJECT/samples/sample-layaways.csv" <<'EOF'
layaway_id,customer_name,phone,created_date,last_payment_date,balance,status
LAY-001,Jane Smith,(212) 555-1234,2024-01-15,2024-02-15,150.00,ACTIVE
LAY-002,Bob Johnson,917-555-6789,2024-02-01,,300.00,ACTIVE
LAY-003,Alice Williams,+13105559999,2024-01-20,2024-03-01,0.00,PAID
LAY-004,Charlie Brown,2125554321,2024-03-01,,75.50,ACTIVE
LAY-005,Diana Prince,(646) 555-8888,2024-02-10,2024-03-10,200.00,ACTIVE
EOF

# ── README.md ────────────────────────────────────────────────────────
cat > "$PROJECT/README.md" <<'READMEEOF'
# Layaway Reminder Engine

A Spring Boot application that manages layaway payment reminders via SMS (Twilio) and online payments (Stripe).

## Prerequisites

- Java 17+
- Maven 3.8+
- Docker & Docker Compose
- ngrok (for webhook testing)
- Stripe CLI (optional, for webhook testing)

## Quick Start

### 1. Start PostgreSQL

```bash
cd layaway-reminder-engine
docker compose up -d
```

### 2. Set Environment Variables

```bash
export DB_URL=jdbc:postgresql://localhost:5432/layaway
export DB_USERNAME=layaway
export DB_PASSWORD=layaway
export APP_ADMIN_API_KEY=your-secret-api-key
export TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export TWILIO_AUTH_TOKEN=your-twilio-auth-token
export TWILIO_FROM_PHONE=+15551234567
export STRIPE_API_KEY=sk_test_xxxxxxxxxxxxxxxxxxxx
export STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxxxxxxxxx
export APP_BASE_URL=https://your-ngrok-url.ngrok.io
export APP_REMINDER_CRON="0 0 10 * * *"
export APP_STORE_TIMEZONE=America/Chicago
export APP_SMS_RATE_PER_SECOND=5
```

### 3. Run the Application

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

Or build and run:

```bash
mvn clean package -DskipTests
java -jar target/layaway-reminder-engine-0.0.1-SNAPSHOT.jar --spring.profiles.active=local
```

### 4. Run Tests

```bash
mvn test
```

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `DB_URL` | PostgreSQL JDBC URL | `jdbc:postgresql://localhost:5432/layaway` |
| `DB_USERNAME` | Database username | `layaway` |
| `DB_PASSWORD` | Database password | `layaway` |
| `APP_ADMIN_API_KEY` | API key for admin endpoints | `change-me-in-production` |
| `APP_REMINDER_CRON` | Cron for daily reminders | `0 0 10 * * *` |
| `APP_STORE_TIMEZONE` | Default store timezone | `America/Chicago` |
| `APP_SMS_RATE_PER_SECOND` | SMS rate limit | `5` |
| `APP_BASE_URL` | Public base URL | `http://localhost:8080` |
| `TWILIO_ACCOUNT_SID` | Twilio Account SID | |
| `TWILIO_AUTH_TOKEN` | Twilio Auth Token | |
| `TWILIO_FROM_PHONE` | Twilio From phone | |
| `STRIPE_API_KEY` | Stripe Secret Key | |
| `STRIPE_WEBHOOK_SECRET` | Stripe Webhook Secret | |
| `SERVER_PORT` | Server port | `8080` |

## Webhook Setup

### ngrok

```bash
ngrok http 8080
```

Use the HTTPS URL from ngrok as your `APP_BASE_URL`.

### Twilio Webhook

1. Go to Twilio Console > Phone Numbers > Your Number
2. Set the **Messaging** webhook to: `https://<ngrok-url>/webhooks/twilio/sms` (HTTP POST)

### Stripe Webhook

Using Stripe CLI for local testing:

```bash
stripe listen --forward-to localhost:8080/webhooks/stripe
```

Copy the webhook signing secret to `STRIPE_WEBHOOK_SECRET`.

For production, create a webhook endpoint in the Stripe Dashboard:
- URL: `https://<your-domain>/webhooks/stripe`
- Events: `checkout.session.completed`

## API Usage

### Configure CSV Mapping (one-time per store)

```bash
# First, create a store (use SQL or admin tool)
# psql: INSERT INTO store (name, phone) VALUES ('My Store', '+15551112222');

# Set CSV mapping
curl -X PUT http://localhost:8080/api/admin/stores/1/csv-mapping \
  -H "X-API-KEY: your-secret-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "mapping": {
      "external_layaway_id": "layaway_id",
      "customer_name": "customer_name",
      "phone": "phone",
      "created_date": "created_date",
      "last_payment_date": "last_payment_date",
      "balance": "balance",
      "status": "status"
    }
  }'
```

### Import CSV

```bash
curl -X POST http://localhost:8080/api/admin/stores/1/imports/csv \
  -H "X-API-KEY: your-secret-api-key" \
  -F "file=@samples/sample-layaways.csv"
```

### Admin Endpoints

```bash
# Get import job status
curl http://localhost:8080/api/admin/imports/1 -H "X-API-KEY: your-secret-api-key"

# List manual review layaways
curl http://localhost:8080/api/admin/layaways/manual-review -H "X-API-KEY: your-secret-api-key"

# List today's reminders
curl http://localhost:8080/api/admin/reminders/today -H "X-API-KEY: your-secret-api-key"

# List call tasks
curl http://localhost:8080/api/admin/call-tasks -H "X-API-KEY: your-secret-api-key"
```

### Health Check

```bash
curl http://localhost:8080/actuator/health
```

## Architecture

- **CSV Import**: Multipart upload with advisory locking, upsert logic, and sync conflict detection
- **Reminder Engine**: Daily @Scheduled job with idempotent send logic and anti-spam
- **Twilio**: Outbound SMS with retry + inbound webhook with signature verification
- **Stripe**: Payment sessions with Checkout, webhook with signature verification and idempotency
- **Observability**: Actuator, Prometheus metrics, correlation ID filter
READMEEOF

# ── Print final instructions ──────────────────────────────────────────
echo ""
echo "============================================================"
echo " layaway-reminder-engine generated successfully!"
echo "============================================================"
echo ""
echo "Next steps:"
echo ""
echo "  1. Start PostgreSQL:"
echo "     cd layaway-reminder-engine && docker compose up -d"
echo ""
echo "  2. Set required environment variables:"
echo "     export APP_ADMIN_API_KEY=your-secret-key"
echo "     export TWILIO_ACCOUNT_SID=ACxxxxxxxx"
echo "     export TWILIO_AUTH_TOKEN=your-auth-token"
echo "     export TWILIO_FROM_PHONE=+15551234567"
echo "     export STRIPE_API_KEY=sk_test_xxxx"
echo "     export STRIPE_WEBHOOK_SECRET=whsec_xxxx"
echo "     export APP_BASE_URL=https://your-ngrok-url.ngrok.io"
echo ""
echo "  3. Run the application:"
echo "     cd layaway-reminder-engine"
echo "     mvn spring-boot:run -Dspring-boot.run.profiles=local"
echo ""
echo "  4. Run tests:"
echo "     mvn test"
echo ""
echo "  5. For webhook testing:"
echo "     ngrok http 8080"
echo "     stripe listen --forward-to localhost:8080/webhooks/stripe"
echo ""
echo "============================================================"
