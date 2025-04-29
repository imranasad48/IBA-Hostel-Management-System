/* Generating rooms that are unoccupied for hostel 1*/

SELECT ROOM_NO, ROOM_TYPE 
FROM ROOMS 
WHERE HOSTEL_ID = 1 AND ROOM_STATUS = 'UNOCCUPIED';

/* Generating the number of unoccupied rooms in each hostel */

SELECT HOSTEL_ID, ROOM_TYPE, COUNT(ROOM_NO) AS "NUMBER OF UNOCCUPIED ROOMS"
FROM ROOMS 
WHERE ROOM_STATUS = 'UNOCCUPIED'
GROUP BY HOSTEL_ID, ROOM_TYPE
ORDER BY HOSTEL_ID;

/* Retrieving all visitors for a specific hostel */

SELECT 
    VISITOR_ID, 
    VISITOR_NAME, 
    ERP_ID, 
    VISIT_DATE, 
    CHECKIN_TIME, 
    CHECKOUT_TIME
FROM 
    VISITOR_LOGS
WHERE 
    HOSTEL_ID = 1
ORDER BY 
    VISIT_DATE DESC;
    
/* Inserting Visitor info when a visitor enters */

CREATE OR REPLACE PROCEDURE visitor_checkin(v_name IN VISITOR_LOGS.VISITOR_NAME%TYPE,host_id IN VISITOR_LOGS.HOSTEL_ID%TYPE, v_erp IN VISITOR_LOGS.ERP_ID%TYPE) AS
BEGIN
    INSERT INTO VISITOR_LOGS(VISITOR_NAME, HOSTEL_ID, ERP_ID)
    VALUES(v_name, host_id,v_erp);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Visitor '||v_name||' entered Hostel '||host_id||' at '||SYSTIMESTAMP);
END;

 -- TEST --

SET SERVEROUTPUT ON
BEGIN
    visitor_checkin('Muhammad Ahmed', 2, 1028);
END;

/* Procedure to update the checkout time */

CREATE OR REPLACE PROCEDURE update_checkout_time (
    p_visitor_id IN VISITOR_LOGS.VISITOR_ID%TYPE
) AS
BEGIN
    -- Update the CHECKOUT_TIME to current timestamp where VISITOR_ID matches and CHECKOUT_TIME is NULL
    UPDATE VISITOR_LOGS
    SET CHECKOUT_TIME = SYSTIMESTAMP
    WHERE VISITOR_ID = p_visitor_id;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No matching visitor log found or already checked out.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Checkout time updated successfully for VISITOR_ID: ' || p_visitor_id);
    END IF;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error updating checkout time: ' || SQLERRM);
END;
/

select * from VISITOR_LOGS;

 -- TEST -- 

SET SERVEROUTPUT ON
BEGIN
    UPDATE_CHECKOUT_TIME(4);
END;

/* Generating requests that are pending from maintenance requests table */

SELECT * 
FROM MAINTENANCE_REQUESTS 
WHERE REQUEST_STATUS = 'Pending';

/* Generating data for inventory items that need repairing/replacement */

SELECT 
    INVENTORY_ID, 
    HOSTEL_ID, 
    INV_TYPE, 
    CONDITION
FROM 
    INVENTORY
WHERE 
    CONDITION = 'Needs repairing/replacement'
ORDER BY 
    HOSTEL_ID, INV_TYPE;

/* Summary Report of Maintenance Requests by Status */

SELECT 
    REQUEST_STATUS, 
    COUNT(*) AS STATUS_COUNT
FROM 
    MAINTENANCE_REQUESTS
GROUP BY 
    REQUEST_STATUS
ORDER BY 
    STATUS_COUNT DESC;

/* Procedure to update Maintenance Request Status */

CREATE OR REPLACE PROCEDURE update_request_status (
    p_request_id IN MAINTENANCE_REQUESTS.REQUEST_ID%TYPE,
    p_new_status IN MAINTENANCE_REQUESTS.REQUEST_STATUS%TYPE
) AS
BEGIN
    IF p_new_status NOT IN ('Pending', 'In-Process', 'Completed') THEN
        DBMS_OUTPUT.PUT_LINE('Invalid REQUEST_STATUS provided.');
    END IF;
    
    UPDATE MAINTENANCE_REQUESTS
    SET 
        REQUEST_STATUS = p_new_status
    WHERE 
        REQUEST_ID = p_request_id;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No maintenance request found with the provided REQUEST_ID.');
    END IF;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Maintenance request status updated successfully for REQUEST_ID: ' || p_request_id);
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error updating maintenance request status: ' || SQLERRM);
END;
/

 -- TEST --

SELECT * FROM MAINTENANCE_REQUESTS;

SET SERVEROUTPUT ON
BEGIN
    update_request_status(2, 'Completed');
END;

/* Procedure to update resident contact information */

CREATE OR REPLACE PROCEDURE update_resident_contact (
    p_erp_id      IN RESIDENTS.ERP_ID%TYPE,
    p_new_contact IN RESIDENTS.CONTACT_INFO_NUMBER%TYPE,
    p_new_email   IN RESIDENTS.CONTACT_INFO_EMAIL%TYPE
) AS
BEGIN
    -- Update the resident's contact number and email
    UPDATE RESIDENTS
    SET 
        CONTACT_INFO_NUMBER = p_new_contact,
        CONTACT_INFO_EMAIL = p_new_email
    WHERE 
        ERP_ID = p_erp_id;
    
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No resident found with the provided ERP_ID.');
    END IF;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Resident contact information updated successfully for ERP_ID: ' || p_erp_id);
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error updating resident contact information: ' || SQLERRM);
END;
/
 -- TEST --

SET SERVEROUTPUT ON
BEGIN
    UPDATE_RESIDENT_CONTACT(1001, 03009833238, 'khan.ahmed@iba.edu.pk');
END;

/* Procedure to delete resident information */

CREATE OR REPLACE PROCEDURE DELETE_RESIDENT (
    p_erp_id IN RESIDENTS.ERP_ID%TYPE
) AS
    v_room_id ROOMS.ROOM_ID%TYPE;
    v_room_type ROOMS.ROOM_TYPE%TYPE;
BEGIN
    -- Fetch the room_id and room_type associated with the resident
    SELECT R.ROOM_ID, ROOM_TYPE INTO v_room_id, v_room_type
    FROM RESIDENTS R LEFT JOIN ROOMS RO ON R.ROOM_ID = RO.ROOM_ID
    WHERE ERP_ID = p_erp_id;

    -- Delete from dependent tables first
    DELETE FROM MESS
    WHERE ERP_ID = p_erp_id;

    DELETE FROM LAUNDRY
    WHERE ERP_ID = p_erp_id;

    DELETE FROM VISITOR_LOGS
    WHERE ERP_ID = p_erp_id;

    DELETE FROM MAINTENANCE_REQUESTS
    WHERE ERP_ID = p_erp_id;

    DELETE FROM PAYMENTS
    WHERE ERP_ID = p_erp_id;

    -- Delete the resident's record
    DELETE FROM RESIDENTS
    WHERE ERP_ID = p_erp_id;

    -- Update the room status if the room is 'single'
    IF v_room_type = 'SINGLE' THEN
        UPDATE ROOMS
        SET ROOM_STATUS = 'UNOCCUPIED'
        WHERE ROOM_ID = v_room_id;
    END IF;

    -- Confirmation message
    IF SQL%ROWCOUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Resident with ERP ID ' || p_erp_id || ' has been removed successfully.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('No resident found with ERP ID ' || p_erp_id || '.');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No resident found with ERP ID ' || p_erp_id || '.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END;
/


 -- TEST -- 
SET SERVEROUTPUT ON
BEGIN
    DELETE_RESIDENT(1017);
END;

/* Procedure to insert new resident information */

CREATE OR REPLACE PROCEDURE INSERT_NEW_RESIDENT (
    p_erp_id IN RESIDENTS.ERP_ID%TYPE,
    p_hostel_id IN RESIDENTS.HOSTEL_ID%TYPE,
    p_room_id IN RESIDENTS.ROOM_ID%TYPE,
    p_first_name IN RESIDENTS.R_FIRST_NAME%TYPE,
    p_last_name IN RESIDENTS.R_LAST_NAME%TYPE,
    p_program IN RESIDENTS.PROGRAM%TYPE,
    p_batch IN RESIDENTS.BATCH%TYPE,
    p_email IN RESIDENTS.CONTACT_INFO_EMAIL%TYPE,
    p_contact_number IN RESIDENTS.CONTACT_INFO_NUMBER%TYPE,
    p_emergency_contact_name IN RESIDENTS.EMERGENCY_CONTACT_NAME%TYPE,
    p_emergency_contact_relation IN RESIDENTS.EMERGENCY_CONTACT_RELATION%TYPE,
    p_emergency_contact_number IN RESIDENTS.EMERGENCY_CONTACT_NUMBER%TYPE
) AS
    v_room_status VARCHAR2(255);
    v_room_type VARCHAR2(255);
BEGIN
    -- Fetch room details
    SELECT ROOM_TYPE, ROOM_STATUS INTO v_room_type, v_room_status
    FROM ROOMS
    WHERE ROOM_ID = p_room_id;

    -- Check room status and type
    IF v_room_status = 'OCCUPIED' AND v_room_type = 'SINGLE' THEN
        DBMS_OUTPUT.PUT_LINE('The room is already occupied.');
    ELSE
        -- Insert the new resident into the RESIDENTS table
        INSERT INTO RESIDENTS (
            ERP_ID, HOSTEL_ID, ROOM_ID, R_FIRST_NAME, R_LAST_NAME, PROGRAM, BATCH, 
            CONTACT_INFO_EMAIL, CONTACT_INFO_NUMBER, EMERGENCY_CONTACT_NAME, 
            EMERGENCY_CONTACT_RELATION, EMERGENCY_CONTACT_NUMBER
        ) VALUES (
            p_erp_id, p_hostel_id, p_room_id, p_first_name, p_last_name, p_program, 
            p_batch, p_email, p_contact_number, p_emergency_contact_name, 
            p_emergency_contact_relation, p_emergency_contact_number
        );

        -- Update the room status to 'OCCUPIED'
        UPDATE ROOMS
        SET ROOM_STATUS = 'OCCUPIED'
        WHERE ROOM_ID = p_room_id;

        -- Confirmation message
        DBMS_OUTPUT.PUT_LINE('New resident added successfully with ERP ID: ' || p_erp_id);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END;
/


-- TEST --
SET SERVEROUTPUT ON
BEGIN
 INSERT_NEW_RESIDENT(1116, 2, 58, 'Sami', 'Rehman', 'BBA', 2028, 'sami.rehman@iba.edu.pk',03129823762, 'ABC', 'Father', 03129882732);
END;

 /* TABLE TO LOG MAINTENANCE REQUESTS MARKED 'COMPLETED' */
 
CREATE TABLE MAINTENANCE_REQUESTS_LOG (
    LOG_ID NUMBER(10) PRIMARY KEY,
    REQUEST_ID NUMBER(10) NOT NULL,
    LOG_DATE DATE DEFAULT SYSDATE,
    LOG_DESCRIPTION VARCHAR2(500),
    FOREIGN KEY (REQUEST_ID) REFERENCES MAINTENANCE_REQUESTS(REQUEST_ID)
);

-- Creating Sequence for LOG_ID
CREATE SEQUENCE maintenance_log_seq
    START WITH 6001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;
/

-- Creating Trigger to Auto-Generate LOG_ID
CREATE OR REPLACE TRIGGER maintenance_log_trigger
    BEFORE INSERT ON MAINTENANCE_REQUESTS_LOG
    FOR EACH ROW
BEGIN
    IF :NEW.LOG_ID IS NULL THEN
        SELECT maintenance_log_seq.NEXTVAL INTO :NEW.LOG_ID FROM dual;
    END IF;
END;
/

 -- Whenever a maintenance request is marked as 'Completed', the trigger inserts
 -- a corresponding record into the MAINTENANCE_REQUESTS_LOG table.

CREATE OR REPLACE TRIGGER trg_log_completed_request
    AFTER UPDATE OF REQUEST_STATUS ON MAINTENANCE_REQUESTS
    FOR EACH ROW
    WHEN (NEW.REQUEST_STATUS = 'Completed' AND OLD.REQUEST_STATUS <> 'Completed')
BEGIN
    INSERT INTO MAINTENANCE_REQUESTS_LOG (
        REQUEST_ID, 
        LOG_DATE, 
        LOG_DESCRIPTION
    ) VALUES (
        :NEW.REQUEST_ID, 
        SYSDATE, 
        'Maintenance request marked as Completed.'
    );
END;
/

/* Total amount generated through Laundry payments (Input: Laundry period) */

CREATE OR REPLACE PROCEDURE laundry_amount(
    period IN LAUNDRY.LAUNDRY_PERIOD%TYPE,
    laundry_total OUT NUMBER
) AS
BEGIN
    SELECT SUM(P.AMOUNT)
    INTO laundry_total
    FROM PAYMENTS P
    JOIN LAUNDRY L ON P.PAYMENT_ID = L.PAYMENT_ID
    WHERE L.LAUNDRY_PERIOD = period;
    DBMS_OUTPUT.PUT_LINE('The laundry total for '|| period || ' is ' ||laundry_total);
END;

SET SERVEROUTPUT ON
DECLARE
    l_period VARCHAR2(255) := 'Fall 2024';
    total NUMBER;
BEGIN
    laundry_amount(l_period, total);
END;

/* Total amount generated through Mess Payments (Input: Mess period) */

CREATE OR REPLACE PROCEDURE mess_amount(
    period IN MESS.MESS_PERIOD%TYPE,
    mess_total OUT NUMBER
) AS
BEGIN
    SELECT SUM(P.AMOUNT)
    INTO mess_total
    FROM PAYMENTS P
    JOIN MESS M ON P.PAYMENT_ID = M.PAYMENT_ID
    WHERE M.MESS_PERIOD = period;
    DBMS_OUTPUT.PUT_LINE('The mess total for '|| period || ' is ' ||mess_total);
END;

SET SERVEROUTPUT ON;
DECLARE
    total NUMBER;
    period VARCHAR2(255) := 'November 2024';
BEGIN
    MESS_AMOUNT(period, total);
END;
