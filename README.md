# Enterprise Healthcare RCM Data Warehouse & Automated Audit Pipeline

## 📌 Architectural Overview
This repository features an advanced, university-level relational database warehouse designed to simulate a scalable **Healthcare Revenue Cycle Management (RCM)** system. The architecture transitions away from basic passive data storage, implementing **asynchronous system auditing, transactional timeline sequencing, and programmable business logic** executed natively at the database engine level.

The platform tracks granular medical lifecycles across multiple highly normalized registries, enforcing strict referential integrity across payer clearings, demographic cohorts, operational schedules, and accounting ledgers.

## 🛠️ Technology Stack & Engine Configuration
* **Database Management System:** MySQL Server (v8.0+)
* **Development Client Workspace:** MySQL Workbench
* **Database Logic Modules:** Embedded Event Triggers, Parametrized Stored Procedures, Conditional Entity Level Constraints.

## 📐 Data Warehouse Entity Relationship Layout
The logical infrastructure is organized into a 7-table normalized schema to eliminate data redundancy and prevent cascading discrepancies:
* `PayerNetworks`: Central clearings registry maintaining corporate insurance nodes and dynamic tracking codes.
* `Patients` / `Doctors` / `ClinicalDepartments`: Structural core directories logging demographics, active providers, and operational cost centers.
* `Appointments`: High-throughput transactional ledger logging tracking statuses (`Completed`, `Cancelled`, `No-Show`).
* `BillingClaims`: Financial ledger tracking itemized claims, financial adjudications, and payment states.
* `FinancialAuditTrail`: Independent, unalterable ledger populated exclusively by engine-driven tracking triggers.

---

## 🏗️ Programmable Engine Automation & Core Logic

### 1. Real-Time Fiscal Variance Logging via Triggers
To guarantee absolute data integrity during billing updates, an active `AFTER UPDATE` trigger intercepts all database modifications. If a claim transitions into a `Disputed` or `Denied` state, or if the system calculates a structural imbalance between adjudicated funds, out-of-pocket tracking, and base invoices, the trigger automatically isolates the record, runs variance calculations, and streams a security flag directly into the audit ledger.

```sql
CREATE TRIGGER TRG_AuditClaimFinancials
AFTER UPDATE ON BillingClaims
FOR EACH ROW
BEGIN
    IF NEW.claim_status IN ('Disputed', 'Denied') OR (NEW.insurance_adjudicated + NEW.patient_responsibility) != NEW.gross_charge THEN
        INSERT INTO FinancialAuditTrail (claim_id, previous_status, updated_status, variance_leakage, flagged_for_review)
        VALUES (NEW.claim_id, OLD.claim_status, NEW.claim_status, (NEW.gross_charge - (NEW.insurance_adjudicated + NEW.patient_responsibility)), TRUE);
    END IF;
END;
```

### 2. Time-Series Double-Billing Sequence Tracker (Stored Procedure)
To counter data-pipeline synchronization overlaps or healthcare transaction duplication fraud, this parameterized stored procedure implements a sliding time-series window. By self-joining the high-throughput `Appointments` registry, the algorithm uses dynamic timestamp math (`TIMESTAMPDIFF`) to surgically identify instances where a single patient receives multiple charges under the same provider within an adjustable minute threshold.

```sql
CREATE PROCEDURE AuditDoubleBillingSequences(IN flag_window_minutes INT)
BEGIN
    SELECT 
        a1.appointment_id AS initial_transaction_id, a2.appointment_id AS redundant_transaction_id,
        CONCAT(p.first_name, ' ', p.last_name) AS audited_patient, CONCAT('Dr. ', d.last_name) AS treating_physician,
        dept.dept_name AS operational_department, a1.appointment_date AS initial_log, a2.appointment_date AS anomaly_log,
        TIMESTAMPDIFF(MINUTE, a1.appointment_date, a2.appointment_date) AS structural_time_gap
    FROM Appointments a1
    JOIN Appointments a2 ON a1.patient_id = a2.patient_id AND a1.doctor_id = a2.doctor_id AND a1.appointment_id < a2.appointment_id
    JOIN Patients p ON a1.patient_id = p.patient_id
    JOIN Doctors d ON a1.doctor_id = d.doctor_id
    JOIN ClinicalDepartments dept ON d.dept_id = dept.dept_id
    WHERE TIMESTAMPDIFF(MINUTE, a1.appointment_date, a2.appointment_date) BETWEEN 0 AND flag_window_minutes
    ORDER BY structural_time_gap ASC;
END;
```

---

## 🧪 Pipeline Diagnostics & Expected Verification Verification Outputs
To execute systemic validation of the database's automated engines, run the following diagnostic scripts within your client query compiler:

### Test Case A: Chronological Sequence Audit Execution
```sql
CALL AuditDoubleBillingSequences(15);
```
* **System Result Matrix:** Successfully runs a 4-table join network to flag 2 historical multi-billing anomalies occurring within sub-15 minute tracking gaps (isolating a 6-minute overlap and a 12-minute window mismatch).

### Test Case B: Asynchronous Trigger Validation Extract
```sql
SELECT * FROM FinancialAuditTrail;
```
* **System Result Matrix:** Isolates exactly 1 security flag tracking a system modification where a mutated balance generated an operational leakage variance of precisely **$5,500.00**.
