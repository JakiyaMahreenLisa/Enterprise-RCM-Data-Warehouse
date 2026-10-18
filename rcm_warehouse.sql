-- ==============================================================================
-- ENTERPRISE HEALTHCARE REVENUE CYCLE MANAGEMENT (RCM) DATA WAREHOUSE
-- Engineering Portfolio - Advanced University-Level Implementation
-- Targeted Database Engine: MySQL 8.0+
-- ==============================================================================

DROP DATABASE IF EXISTS ComplexHealthcareRCM_DB;
CREATE DATABASE ComplexHealthcareRCM_DB;
USE ComplexHealthcareRCM_DB;

-- ------------------------------------------------------------------------------
-- 1. SCHEMATIC CORE REGISTRIES
-- ------------------------------------------------------------------------------
CREATE TABLE PayerNetworks (
    payer_id INT PRIMARY KEY AUTO_INCREMENT,
    payer_name VARCHAR(100) NOT NULL UNIQUE,
    clearinghouse_code VARCHAR(20) NOT NULL UNIQUE,
    reimbursement_rate_pct DECIMAL(5,2) NOT NULL CHECK (reimbursement_rate_pct BETWEEN 0.00 AND 100.00)
);

CREATE TABLE Patients (
    patient_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender ENUM('Male', 'Female', 'Other') NOT NULL,
    primary_payer_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (primary_payer_id) REFERENCES PayerNetworks(payer_id) ON DELETE SET NULL
);

CREATE TABLE ClinicalDepartments (
    dept_id INT PRIMARY KEY AUTO_INCREMENT,
    dept_name VARCHAR(50) NOT NULL UNIQUE,
    cost_center_code VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE Doctors (
    doctor_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    specialty VARCHAR(50) NOT NULL,
    dept_id INT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (dept_id) REFERENCES ClinicalDepartments(dept_id)
);

-- ------------------------------------------------------------------------------
-- 2. OPERATIONAL TRANSACTION LEDGERS
-- ------------------------------------------------------------------------------
CREATE TABLE Appointments (
    appointment_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_id INT NOT NULL,
    doctor_id INT NOT NULL,
    appointment_date DATETIME NOT NULL,
    status ENUM('Scheduled', 'Completed', 'Cancelled', 'No-Show') DEFAULT 'Scheduled',
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id) ON DELETE RESTRICT,
    FOREIGN KEY (doctor_id) REFERENCES Doctors(doctor_id) ON DELETE RESTRICT
);

CREATE TABLE BillingClaims (
    claim_id INT PRIMARY KEY AUTO_INCREMENT,
    appointment_id INT UNIQUE NOT NULL,
    gross_charge DECIMAL(10, 2) NOT NULL CHECK (gross_charge >= 0),
    insurance_adjudicated DECIMAL(10, 2) DEFAULT 0.00 CHECK (insurance_adjudicated >= 0),
    patient_responsibility DECIMAL(10, 2) DEFAULT 0.00 CHECK (patient_responsibility >= 0),
    claim_status ENUM('Admitted', 'Paid', 'Partially_Paid', 'Disputed', 'Denied') DEFAULT 'Admitted',
    submission_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES Appointments(appointment_id) ON DELETE CASCADE
);

CREATE TABLE FinancialAuditTrail (
    audit_id INT PRIMARY KEY AUTO_INCREMENT,
    claim_id INT,
    previous_status VARCHAR(20),
    updated_status VARCHAR(20),
    variance_leakage DECIMAL(10, 2),
    flagged_for_review BOOLEAN DEFAULT FALSE,
    action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 3. EMBEDDED ENGINE AUTOMATION (Triggers & Procedures)
-- ------------------------------------------------------------------------------
DELIMITER $$

-- Trigger to automatically track processing leakages during claim alterations
CREATE TRIGGER TRG_AuditClaimFinancials
AFTER UPDATE ON BillingClaims
FOR EACH ROW
BEGIN
    -- Flag if the system detects that total calculated balances do not match historical base costs
    IF NEW.claim_status IN ('Disputed', 'Denied') OR (NEW.insurance_adjudicated + NEW.patient_responsibility) != NEW.gross_charge THEN
        INSERT INTO FinancialAuditTrail (claim_id, previous_status, updated_status, variance_leakage, flagged_for_review)
        VALUES (
            NEW.claim_id, 
            OLD.claim_status, 
            NEW.claim_status, 
            (NEW.gross_charge - (NEW.insurance_adjudicated + NEW.patient_responsibility)), 
            TRUE
        );
    END IF;
END$$

-- Complex Analytical Procedure for Sequenced Processing Anomaly Tracking
CREATE PROCEDURE AuditDoubleBillingSequences(IN flag_window_minutes INT)
BEGIN
    SELECT 
        a1.appointment_id AS initial_transaction_id,
        a2.appointment_id AS redundant_transaction_id,
        CONCAT(p.first_name, ' ', p.last_name) AS audited_patient,
        CONCAT('Dr. ', d.last_name) AS treating_physician,
        dept.dept_name AS operational_department,
        a1.appointment_date AS initial_log,
        a2.appointment_date AS anomaly_log,
        TIMESTAMPDIFF(MINUTE, a1.appointment_date, a2.appointment_date) AS structural_time_gap
    FROM Appointments a1
    JOIN Appointments a2 ON a1.patient_id = a2.patient_id 
        AND a1.doctor_id = a2.doctor_id 
        AND a1.appointment_id < a2.appointment_id
    JOIN Patients p ON a1.patient_id = p.patient_id
    JOIN Doctors d ON a1.doctor_id = d.doctor_id
    JOIN ClinicalDepartments dept ON d.dept_id = dept.dept_id
    WHERE TIMESTAMPDIFF(MINUTE, a1.appointment_date, a2.appointment_date) BETWEEN 0 AND flag_window_minutes
    ORDER BY structural_time_gap ASC;
END$$

DELIMITER ;

-- ------------------------------------------------------------------------------
-- 4. HIGH-DENSITY ENTERPRISE SEED DATA
-- ------------------------------------------------------------------------------
INSERT INTO PayerNetworks (payer_name, clearinghouse_code, reimbursement_rate_pct) VALUES
('Blue Cross Shield', 'BCBS881', 85.00),
('Aetna Healthcare', 'AET992', 80.00),
('UnitedHealth Group', 'UHG441', 75.00);

INSERT INTO Patients (first_name, last_name, date_of_birth, gender, primary_payer_id) VALUES
('Asif', 'Iqbal', '1991-03-24', 'Male', 1),
('Nusrat', 'Imrose', '1995-07-12', 'Female', 2),
('Zeeshan', 'Haq', '1984-11-02', 'Male', 3),
('Tasnim', 'Fariha', '2002-05-19', 'Female', NULL),
('Arif', 'Hasan', '1989-12-14', 'Male', 1),
('Mitu', 'Chowdhury', '1993-04-21', 'Female', 2);

INSERT INTO ClinicalDepartments (dept_name, cost_center_code) VALUES
('Internal Medicine', 'CC-INT-01'),
('Neuroscience', 'CC-NEUR-02'),
('Pediatrics', 'CC-PED-03');

INSERT INTO Doctors (first_name, last_name, specialty, dept_id) VALUES
('Tanvir', 'Ahmed', 'Cardiology', 1),
('Sabrina', 'Rashid', 'Neurology', 2),
('Imran', 'Khan', 'Pediatrics', 3);

-- Seeding complex transaction loops (Including intentional sub-10 minute double billing loops)
INSERT INTO Appointments (patient_id, doctor_id, appointment_date, status) VALUES
(1, 1, '2026-10-19 09:00:00', 'Completed'),
(1, 1, '2026-10-19 09:06:00', 'Completed'), -- Double billing loop instance 1
(2, 1, '2026-10-19 10:00:00', 'Completed'),
(3, 2, '2026-10-19 11:00:00', 'Completed'),
(4, 3, '2026-10-19 13:00:00', 'Completed'),
(5, 2, '2026-10-19 14:00:00', 'Completed'),
(5, 2, '2026-10-19 14:12:00', 'Completed'), -- Double billing loop instance 2
(6, 3, '2026-10-19 15:30:00', 'Cancelled');

INSERT INTO BillingClaims (appointment_id, gross_charge, insurance_adjudicated, patient_responsibility, claim_status) VALUES
(1, 5000.00, 4250.00, 750.00, 'Paid'),
(2, 5000.00, 0.00, 0.00, 'Admitted'), -- Anomaly charge tracking target
(3, 1500.00, 1200.00, 300.00, 'Paid'),
(4, 9000.00, 6750.00, 2250.00, 'Paid'),
(5, 2200.00, 0.00, 2200.00, 'Paid'),
(6, 4500.00, 3375.00, 1125.00, 'Paid'),
(7, 4500.00, 0.00, 0.00, 'Admitted'); -- Anomaly charge tracking target

-- ------------------------------------------------------------------------------
-- 5. INTERACTIVE LIVE TRANSACTION SYSTEM EMULATION
-- ------------------------------------------------------------------------------
-- Trigger active processing check by creating a dynamic financial dispute record alteration
UPDATE BillingClaims SET claim_status = 'Disputed', insurance_adjudicated = 3000.00, patient_responsibility = 500.00 WHERE claim_id = 4;
