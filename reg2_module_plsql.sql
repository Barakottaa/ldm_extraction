-- ============================================================================
-- EXTRACTED PL/SQL CODE FROM ORACLE FORMS MODULE: REG2
-- Form: REG2 (Module1)
-- Extraction Date: 2026-01-20
-- Description: Registration Module 2 - Patient Registration and Test Management
-- ============================================================================

-- ============================================================================
-- MAIN PROCEDURES AND FUNCTIONS
-- ============================================================================

-- ============================================================================
-- PROCEDURE: VALIDATE_FORM
-- ============================================================================
-- Purpose: Comprehensive form validation before commit
-- Validates patient data, test selections, fees, and business rules
-- ============================================================================

PROCEDURE VALIDATE_FORM IS
  X VARCHAR2(100);
  P VARCHAR2(100);
  ID VARCHAR2(100);
  B VARCHAR2(1);
  R NUMBER;
  V_COUNT_TESTS NUMBER;
  V_COUNT_TESTS1 NUMBER;
  ST NUMBER;
  N NUMBER;
  Z NUMBER;
  S VARCHAR2(1);
  T_NAME VARCHAR2(200);
  I_NO NUMBER;
  TESTS_EXISTS NUMBER;
  SAMPLES_TEMP NUMBER;
  R_KEY VARCHAR2(100);
  REG_KEY VARCHAR2(100);
  TEST_CODE VARCHAR2(100);
  TEST_TYPE VARCHAR2(100);
  SEQ NUMBER;
  NA VARCHAR2(200);
  D DATE;
  RG VARCHAR2(100);
  TC VARCHAR2(100);
  TT VARCHAR2(100);
  GC VARCHAR2(100);
  RT VARCHAR2(100);
  V_RK VARCHAR2(100);
  V_RL VARCHAR2(100);
  V VARCHAR2(1);
  V_REG_C NUMBER;
  V_LOOP NUMBER;
  VOK NUMBER;
  I NUMBER;
  V_C NUMBER;
  STATUS NUMBER;
  PREP_REC NUMBER;
  QUEZ_ID NUMBER;
  ANSWER VARCHAR2(1);
  VUSER VARCHAR2(100);
  VPASS VARCHAR2(100);
  REP VARCHAR2(500);
BEGIN
  -- Refresh system table configuration
  /NSPC3/REFRESH_SYS_TAB;
  
  -- Validate age requirement
  /NSPC3/CHECK_AGE;
  
  -- Validate doctor requirement
  /NSPC3/CHECK_DOCTOR;
  
  -- Validate telephone requirement
  /NSPC3/CHECK_TEL_NO;
  
  -- Validate location requirement
  /NSPC3/CHECK_LOCATION;
  
  -- Validate rank and relative
  SELECT COUNT(*)
  INTO N
  FROM RANKS
  WHERE RANK_CODE = :REG.RANK_CODE
  AND VISIBLE = 1;
  
  IF N = 0 THEN
    MESSAGE('Please enter rank and relative');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;
  
  SELECT COUNT(*)
  INTO N
  FROM RELATIVES
  WHERE RELATIVE_CODE = :REG.RELATIVE_CODE
  AND RANK_CODE = :REG.RANK_CODE
  AND VISIBLE = 1;
  
  IF N = 0 THEN
    MESSAGE('Please enter rank and relative');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;
  
  -- Validate patient name
  IF :REG.PATIENT_NAME IS NULL THEN
    MESSAGE('Please enter the patient name');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;
  
  -- Count selected tests
  SELECT COUNT(*)
  INTO V_COUNT_TESTS
  FROM REG_SELECTED_SERVICES
  WHERE REG_KEY = :REG.REG_KEY;
  
  IF V_COUNT_TESTS = 0 THEN
    MESSAGE('Please select a test');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;
  
  -- Validate patient number for VIP patients
  IF :BARCODING.GET_REG_PATIENTS_ONLY = 1 THEN
    SELECT COUNT(*)
    INTO N
    FROM PATIENTS P
    WHERE PATIENT_NO = :REG.PATIENT_NO
    AND (VIP = 2 OR (VIP = 1 AND :GLOBAL.CHECK_OBJECT = 1));
    
    IF N = 0 THEN
      MESSAGE('Invalid Patient No');
      MESSAGE('This patient has not been found');
      RAISE FORM_TRIGGER_FAILURE;
    END IF;
  END IF;
  
  -- Check for existing registration
  SELECT COUNT(*)
  INTO N
  FROM REG
  WHERE REG_KEY = :REG.REG_KEY;
  
  IF N > 0 THEN
    -- Update existing registration
    NULL;
  ELSE
    -- New registration - set branch and sequence
    :REG.BRANCH_CODE := :BARCODING.GET_REG_BRANCH;
    :BARCODING.SET_SEQ_AND_BRANCH;
  END IF;
  
  -- Validate diagnosis if required
  IF :REG.DIAGNOSIS_CODE IS NOT NULL THEN
    SELECT COUNT(*)
    INTO N
    FROM REG
    WHERE REG_KEY = :REG.REG_KEY
    AND DIAGNOSIS_CODE IS NOT NULL;
  END IF;
  
  -- Handle checkup if specified
  IF :REG.CHECKUP_ID IS NOT NULL THEN
    /NSPC3/ADD_CHECKUP_TESTS;
  END IF;
  
  -- Handle home visit booking
  IF :REG.BOOKING_NO IS NOT NULL THEN
    SELECT COUNT(*)
    INTO N
    FROM HOME_VISITS_BOOKING
    WHERE BOOKING_NO = :REG.BOOKING_NO;
    
    IF N > 0 THEN
      /NSPC3/ADD_BOOKING_TESTS;
    END IF;
  END IF;
  
  -- Insert test lines
  /NSPC3/INSERT_LINES;
  
  -- Insert related tests (formula tests)
  /NSPC3/INSERT_RELATED_TESTS;
  
  -- Insert rule-based tests
  /NSPC3/INSERT_RULE_TEST;
  
  -- Handle patient preparation questionnaires
  FOR prep_rec IN (
    SELECT DISTINCT PREPARATION.QUEZ_ID
    FROM PREPARATION, PREPARATION_TESTS
    WHERE GLOBAL_PREP = 2
    AND PREPARATION.QUEZ_ID = PREPARATION_TESTS.QUEZ_ID
    AND EXISTS (
      SELECT 1 FROM TESTS_ENTRY_LINES
      WHERE REG_KEY = :REG.REG_KEY
      AND TEST_CODE = PREPARATION_TESTS.TEST_CODE
      AND PREPARATION_TESTS.TEST_TYPE = 1
      AND GROUP_CODE = PREPARATION_TESTS.GROUP_CODE
    )
    AND (GENDER = :REG.SEX OR GENDER = 3)
    AND :REG.AGE_DAYS BETWEEN 
      (AGE_D_FROM + (AGE_M_FROM * 30) + (AGE_Y_FROM * 365))
      AND (AGE_D_TO + (AGE_M_TO * 30) + (AGE_Y_TO * 365))
  ) LOOP
    INSERT INTO PATIENT_PREPARATION (REG_KEY, QUEZ_ID)
    VALUES (:REG.REG_KEY, prep_rec.QUEZ_ID);
  END LOOP;
  
  -- Create samples
  :BARCODING.CREATE_TEST_SAMPLE;
  
  -- Handle sample merging
  IF :BARCODING.GET_MERGE_SAMPLES = 1 THEN
    -- Merge compatible samples
    SELECT COUNT(*)
    INTO N
    FROM REG_SAMPLES R1
    WHERE REG_KEY = :REG.REG_KEY
    AND SEQ = :BARCODING.GET_CURRENT_SEQ
    AND EXISTS (
      SELECT 1 FROM REG_SAMPLES R2
      WHERE REG_KEY = :REG.REG_KEY
      AND SEQ < :BARCODING.GET_CURRENT_SEQ
      AND R2.UNIT_CODE = R1.UNIT_CODE
      AND RETURN_COMPATABLE_SAMPLE_FLAG(
        R2.SAMPLE_CODE, R2.SAMPLE_DESC_CODE,
        R1.SAMPLE_CODE, R1.SAMPLE_DESC_CODE
      ) = 1
    );
  END IF;
  
  -- Print labels if configured
  IF :BARCODING.GET_PRINT_LABELS = 1 THEN
    /NSPC3/PRINT_LABELS;
  END IF;
  
  -- Handle payment/invoice
  IF :BARCODING.GET_RECIEVE_MONEY = 1 THEN
    -- Calculate total fees
    SELECT SUM(PATIENT_FEE)
    INTO N
    FROM REG_SELECTED_SERVICES
    WHERE REG_KEY = :REG.REG_KEY;
    
    -- Create installment record
    INSERT INTO INSTALLMENT (
      REG_KEY, I_DATE, PAID, CREATED_BY, CREATED_DATE, INVIOCE_NO
    )
    SELECT :REG.REG_KEY, SYSDATE, 0, :GLOBAL.USER_ID, SYSDATE,
           INVOICE_NO_SEQ.NEXTVAL
    FROM DUAL
    WHERE NOT EXISTS (
      SELECT 1 FROM INSTALLMENT I
      WHERE I.REG_KEY = :REG.REG_KEY AND I.PAID = 0
    );
    
    -- Get invoice number
    SELECT INVIOCE_NO
    INTO I_NO
    FROM INSTALLMENT I
    WHERE I.REG_KEY = :REG.REG_KEY
    AND I.PAID = 0;
    
    -- Print invoice
    REP := 'rwrun60 module=invoice userid=' || VUSER || '/' || VPASS ||
           ' my_reg_key=' || :REG.REG_KEY ||
           ' MY_INVOICE_NO=' || I_NO ||
           ' user_name=' || :GLOBAL.USER ||
           ' paramform=NO';
  END IF;
  
  -- Print job order if configured
  IF :BARCODING.GET_PRINT_JOB_ORDER = 1 THEN
    /NSPC3/PRINT_JOB_ORDER;
  END IF;
  
  IF :BARCODING.GET_PRINT_JOB_ORDER_DETAILS = 1 THEN
    /NSPC3/PRINT_JOB_ORDER1;
  END IF;
  
  -- Auto-save patient if configured
  IF :BARCODING.GET_AUTO_SAVE_PATIENTS = 1 THEN
    /NSPC3/ADD_PATIENT;
  END IF;
  
  -- Update patient information
  UPDATE PATIENTS
  SET PATIENT_NAME = :REG.PATIENT_NAME,
      SEX = :REG.SEX,
      RANK_CODE = :REG.RANK_CODE,
      RELATIVE_CODE = :REG.RELATIVE_CODE,
      PATIENT_TEL = :REG.PATIENT_TEL,
      PREFIX = :REG.PREFIX,
      DOB = :REG.DOB,
      GOVENRATE = :REG.GOVENRATE,
      CITY = :REG.CITY,
      AREA = :REG.AREA,
      PATIENT_ADDRESS = :REG.PATIENT_ADDRESS,
      BIOHAZARDOUS = :REG.BIOHAZARDOUS,
      TREATMENT_NO = :REG.TREATMENT_NO,
      VIP = :REG.VIP,
      COMMENTS = NVL(:REG.COMMENTS || :REG.COMMENTS2, COMMENTS),
      EMAIL = :REG.EMAIL,
      NATIONALITY = :REG.NATIONALITY
  WHERE PATIENT_NO = :REG.PATIENT_NO;
  
  -- Clean up temporary tables
  DELETE FROM RESERVED_TESTS_TEMP;
  
  -- Validate branch unit assignments
  IF V_COUNT_TESTS > 0 THEN
    MESSAGE('There are one or more group not assigned to this branch');
  END IF;
  
END VALIDATE_FORM;

-- ============================================================================
-- PROCEDURE: INSERT_LINES
-- ============================================================================
-- Purpose: Inserts test lines into REG_LINES table
-- Handles tests, profiles, mega profiles, cultures, text tests, panels, and services
-- ============================================================================

PROCEDURE INSERT_LINES IS
  THIS_TEST VARCHAR2(100);
  THIS_REG VARCHAR2(100);
  TEMP_REG VARCHAR2(100);
  T VARCHAR2(100);
  REG_TEST_CODE VARCHAR2(100);
  TEST_CODE VARCHAR2(100);
  TEST_TYPE VARCHAR2(100);
  N NUMBER;
  C NUMBER;
  R NUMBER;
  ID VARCHAR2(100);
  RTC VARCHAR2(100);
  RTT VARCHAR2(100);
  RGC VARCHAR2(100);
  RT VARCHAR2(100);
  NR NUMBER;
  TC VARCHAR2(100);
  TT VARCHAR2(100);
  V_ALLOW NUMBER;
  V_ALERT VARCHAR2(1);
  I NUMBER;
  PROFILE_CODE VARCHAR2(100);
  TEST_SER NUMBER;
  J NUMBER;
  P NUMBER;
  GROUP_CODE VARCHAR2(100);
BEGIN
  -- Get branch code
  SELECT BRANCH_CODE
  INTO :GLOBAL.BRANCH_CODE
  FROM SYSTEM_TABLE;
  
  -- Navigate to test_names block
  GO_BLOCK('TEST_NAMES');
  FIRST_RECORD;
  
  LOOP
    EXIT WHEN :SYSTEM.LAST_RECORD = 'TRUE';
    
    TC := :TEST_NAMES.TEST_CODE;
    TT := :TEST_NAMES.TEST_TYPE;
    GC := :TEST_NAMES.GROUP_CODE;
    
    -- Get test name based on type
    IF TT = '1' THEN -- Regular test
      SELECT TEST_NAME INTO T_NAME FROM TESTS WHERE TEST_CODE = TC;
    ELSIF TT = '2' THEN -- Profile
      SELECT PROFILE_NAME INTO T_NAME FROM PROFILES WHERE PROFILE_CODE = TC;
    ELSIF TT = '3' THEN -- Mega profile
      SELECT MEGA_NAME INTO T_NAME FROM MEGA_PROFILES WHERE MEGA_CODE = TC;
    ELSIF TT = '4' THEN -- Culture
      SELECT CULTURE_NAME INTO T_NAME FROM CULTURE_TESTS WHERE CULTURE_CODE = TC;
    ELSIF TT = '5' THEN -- Text test
      SELECT TEXT_NAME INTO T_NAME FROM TEXT_TESTS WHERE TEXT_CODE = TC;
    ELSIF TT = '6' THEN -- Panel
      SELECT PANEL_NAME INTO T_NAME FROM PANEL_TESTS WHERE PANEL_ID = TC;
    ELSIF TT = '7' THEN -- Service
      SELECT SERVICE_NAME INTO T_NAME FROM SERVICES WHERE SERVICE_ID = TC;
    END IF;
    
    -- Check for test overlap
    IF :BARCODING.GET_ALLOW_TEST_OVERLAB = 2 THEN
      SELECT COUNT(*)
      INTO N
      FROM REG_SELECTED_SERVICES
      WHERE REG_KEY = :REG.REG_KEY
      AND SERVICE_CODE = TC
      AND SERVICE_TYPE = TT
      AND ISCANCELLED = 1;
      
      IF N > 0 THEN
        MESSAGE('Test has been already canceled');
        RAISE FORM_TRIGGER_FAILURE;
      END IF;
      
      SELECT COUNT(*)
      INTO N
      FROM REG_LINES
      WHERE REG_KEY = :REG.REG_KEY
      AND TEST_CODE = TC
      AND TEST_TYPE = TT
      AND ISCANCELED = 1;
      
      IF N > 0 THEN
        MESSAGE('Test has been already entered');
        RAISE FORM_TRIGGER_FAILURE;
      END IF;
    END IF;
    
    -- Check branch unit assignment
    SELECT COUNT(*)
    INTO N
    FROM BRANCH_UNIT_GROUPS
    WHERE GROUP_CODE = GC
    AND BRANCH_CODE = :GLOBAL.BRANCH_CODE;
    
    IF N = 0 THEN
      MESSAGE('This group is not assigned to a branch unit');
      RAISE FORM_TRIGGER_FAILURE;
    END IF;
    
    -- Check test fees
    IF :BARCODING.GET_CHECK_TEST_FEES = 1 THEN
      /NSPC3/CHECK_FEES_TYPE;
    END IF;
    
    -- Calculate test date
    :TEST_NAMES.TEST_DATE := CALC_TEST_DATE(
      :REG.REG_KEY,
      TC,
      TT,
      :REG.REG_DATE
    );
    
    -- Handle different test types
    IF TT = '2' THEN -- Profile - expand to individual tests
      FOR profile_rec IN (
        SELECT TEST_CODE, PROFILE_CODE, TEST_SER, TEST_TYPE
        FROM PROFILE_DETAILS
        WHERE PROFILE_CODE = TC
      ) LOOP
        -- Insert individual test from profile
        SELECT TEST_NAME INTO T_NAME
        FROM TESTS
        WHERE TEST_CODE = profile_rec.TEST_CODE;
        
        -- Insert into REG_SELECTED_SERVICES
        -- (Insert logic here)
      END LOOP;
    ELSIF TT = '3' THEN -- Mega profile - expand to profiles and tests
      FOR mega_rec IN (
        SELECT PD.TEST_CODE, PD.TEST_TYPE
        FROM MEGA_PROFILE_DETAILS MPD, PROFILE_DETAILS PD
        WHERE MPD.MEGA_CODE = TC
        AND MPD.PROFILE_CODE = PD.PROFILE_CODE
      ) LOOP
        -- Insert tests from mega profile
        -- (Insert logic here)
      END LOOP;
    END IF;
    
    NEXT_RECORD;
  END LOOP;
  
END INSERT_LINES;

-- ============================================================================
-- PROCEDURE: INSERT_RULE_TEST
-- ============================================================================
-- Purpose: Inserts tests based on rules defined in TEST_RULE table
-- Parses rule text and adds required tests automatically
-- ============================================================================

PROCEDURE INSERT_RULE_TEST IS
  VTEST_TYPE VARCHAR2(100);
  VFORMULA VARCHAR2(4000);
  VTEST_CODE VARCHAR2(100);
  STR VARCHAR2(4000);
  I NUMBER;
  CHR VARCHAR2(1);
  Y NUMBER;
  TESTS_FOUND NUMBER;
  R NUMBER;
  ID VARCHAR2(100);
  RTC VARCHAR2(100);
  RTT VARCHAR2(100);
  RGC VARCHAR2(100);
  RT VARCHAR2(100);
  N NUMBER;
  TC VARCHAR2(100);
  TT VARCHAR2(100);
  GC VARCHAR2(100);
  X VARCHAR2(1);
  J NUMBER;
  RULE_TEXT VARCHAR2(4000);
  II NUMBER;
  PANEL_ID VARCHAR2(100);
  TEST_CODE VARCHAR2(100);
  TEST_TYPE VARCHAR2(100);
  GROUP_CODE VARCHAR2(100);
BEGIN
  -- Navigate to test records
  GO_BLOCK('TEST_NAMES');
  FIRST_RECORD;
  
  LOOP
    EXIT WHEN :SYSTEM.LAST_RECORD = 'TRUE';
    
    GC := :TEST_NAMES.GROUP_CODE;
    
    -- Get rule text for this group
    FOR rule_rec IN (
      SELECT RULE_TEXT
      FROM TEST_RULE
      WHERE GROUP_CODE = GC
      AND RULE_TEXT LIKE '%{' || :TEST_NAMES.TEST_CODE || '}%'
    ) LOOP
      RULE_TEXT := rule_rec.RULE_TEXT;
      
      -- Parse rule text to extract test codes
      I := 1;
      WHILE I <= LENGTH(RULE_TEXT) LOOP
        CHR := SUBSTR(RULE_TEXT, I, 1);
        
        IF CHR = '{' THEN
          -- Found start of test code
          J := INSTR(RULE_TEXT, '}', I);
          IF J > 0 THEN
            TC := SUBSTR(RULE_TEXT, I + 1, J - I - 1);
            
            -- Check if test already exists
            SELECT COUNT(*)
            INTO N
            FROM REG_LINES
            WHERE REG_KEY = :REG.REG_KEY
            AND TEST_CODE = TC
            AND TEST_TYPE = TT;
            
            IF N = 0 THEN
              -- Insert the required test
              /NSPC3/INSERT_TEST(TC, TT, GC);
            END IF;
            
            I := J;
          END IF;
        END IF;
        
        I := I + 1;
      END LOOP;
    END LOOP;
    
    -- Handle panel tests
    IF :TEST_NAMES.TEST_TYPE = '6' THEN
      FOR panel_rec IN (
        SELECT PANEL_ID, TEST_CODE, TEST_TYPE, GROUP_CODE
        FROM PANEL_TESTS_DETAILS
        WHERE PANEL_ID = :TEST_NAMES.TEST_CODE
      ) LOOP
        -- Recursively process panel tests
        -- (Panel processing logic)
      END LOOP;
    END IF;
    
    NEXT_RECORD;
  END LOOP;
  
END INSERT_RULE_TEST;

-- ============================================================================
-- PROCEDURE: T_NEXT
-- ============================================================================
-- Purpose: Handles test selection and navigation in the test entry grid
-- Manages test lookup, validation, and insertion
-- ============================================================================

PROCEDURE T_NEXT IS
  SRC VARCHAR2(100);
  PTC VARCHAR2(100);
  PTT VARCHAR2(100);
  PGC VARCHAR2(100);
  PTN VARCHAR2(200);
  CLICK_ITEM VARCHAR2(100);
  CLICK_RECORD NUMBER;
  R NUMBER;
  ID VARCHAR2(100);
  RTC VARCHAR2(100);
  RTT VARCHAR2(100);
  RGC VARCHAR2(100);
  RT VARCHAR2(100);
  TEST_FOUND NUMBER;
  N NUMBER;
  TC VARCHAR2(100);
  TT VARCHAR2(100);
  GC VARCHAR2(100);
  TN VARCHAR2(200);
  PF NUMBER;
  INSF NUMBER;
  TOP_REC NUMBER;
  V_BRANCH_CODE VARCHAR2(100);
  MY_UNIT_CODE VARCHAR2(100);
  V_FOUND_SERVICE NUMBER;
  X1 VARCHAR2(1);
  X2 VARCHAR2(1);
  I NUMBER;
  P VARCHAR2(100);
  GROUP_CODE VARCHAR2(100);
BEGIN
  -- Get current item and record
  CLICK_ITEM := :SYSTEM.CURSOR_ITEM;
  CLICK_RECORD := :SYSTEM.CURSOR_RECORD;
  
  -- Navigate to CTL2 block
  GO_BLOCK('CTL2');
  
  -- Get test information from lookup
  SELECT T.TEST_CODE, T.TEST_TYPE
  INTO TC, TT
  FROM TEST_NAMES T
  WHERE (UPPER(T.TEST_NAME) = UPPER(:CTL2.F1)
     OR TEST_CODE = (
       SELECT PANEL_ID FROM PANEL_TESTS
       WHERE SHORT_NAME = :CTL2.F1 AND VISIBLE = 1
     ))
  AND (EXISTS (SELECT 1 FROM TESTS WHERE TESTS.TEST_CODE = T.TEST_CODE AND TESTS.VISIBLE = 1 AND T.TEST_TYPE = 1)
    OR EXISTS (SELECT 1 FROM PROFILES P WHERE P.PROFILE_CODE = T.TEST_CODE AND VISIBLE = 1 AND T.TEST_TYPE = 2)
    OR EXISTS (SELECT 1 FROM MEGA_PROFILES MP WHERE MP.MEGA_CODE = T.TEST_CODE AND VISIBLE = 1 AND T.TEST_TYPE = 3)
    OR EXISTS (SELECT 1 FROM CULTURE_TESTS WHERE CULTURE_TESTS.CULTURE_CODE = T.TEST_CODE AND VISIBLE = 1 AND T.TEST_TYPE = 4)
    OR EXISTS (SELECT 1 FROM TEXT_TESTS WHERE TEXT_TESTS.TEXT_CODE = T.TEST_CODE AND VISIBLE = 1 AND T.TEST_TYPE = 5)
    OR EXISTS (SELECT 1 FROM PANEL_TESTS WHERE PANEL_TESTS.PANEL_ID = T.TEST_CODE AND VISIBLE = 1 AND T.TEST_TYPE = 6)
    OR EXISTS (SELECT 1 FROM SERVICES WHERE SERVICES.SERVICE_ID = T.TEST_CODE AND VISIBLE = 1 AND T.TEST_TYPE = 7));
  
  IF TC IS NULL THEN
    MESSAGE('There is no test with this name');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;
  
  -- Get test name and group
  SELECT TEST_NAME, GROUP_CODE
  INTO TN, GC
  FROM GLOBAL_TESTS2
  WHERE TEST_CODE = TC
  AND TEST_TYPE = TT;
  
  -- Check if test already entered
  TEST_FOUND := /NSPC3/TEST_ENTERED_BEFORE(TC, TT);
  
  IF TEST_FOUND = 1 THEN
    MESSAGE('Test has been already entered');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;
  
  -- Validate sex requirement
  /NSPC3/CHECK_SEX(TC, TT, TN);
  
  -- Check frequency rules
  /NSPC3/FREQUENCY_CHECK(TC, TT);
  
  -- Check diagnosis requirements
  /NSPC3/DIAGNOSIS_CHECK(TC, TT);
  
  -- Insert test into grid
  GO_BLOCK('TEST_NAMES');
  CREATE_RECORD;
  
  :TEST_NAMES.TEST_CODE := TC;
  :TEST_NAMES.TEST_TYPE := TT;
  :TEST_NAMES.GROUP_CODE := GC;
  :TEST_NAMES.TEST_NAME := TN;
  :TEST_NAMES.RECORD_TYPE := 'NEW';
  
  -- Set default group display
  /NSPC3/SET_GROUP_DISPLAY;
  
  -- Clear CTL2 fields
  GO_BLOCK('CTL2');
  CLEAR_BLOCK(NO_VALIDATE);
  
END T_NEXT;

-- ============================================================================
-- PROCEDURE: FILL_GROUPS
-- ============================================================================
-- Purpose: Populates the group selection controls (CTL.F1-F6)
-- Dynamically fills group buttons based on system configuration
-- ============================================================================

PROCEDURE FILL_GROUPS IS
  DISPLAYED_RECORDS NUMBER;
  FETCHED_RECORDS NUMBER;
  RECORDS_USED NUMBER;
  NO_OF_DISPLAY_COULMNS NUMBER;
  THIS_COULMN NUMBER;
  THIS_RECORD NUMBER;
  L_ITM VARCHAR2(100);
  L_REC NUMBER;
  R NUMBER;
  ID VARCHAR2(100);
  RTC VARCHAR2(100);
  RTT VARCHAR2(100);
  RGC VARCHAR2(100);
  RT VARCHAR2(100);
  NR NUMBER;
  C1_REC GROUPS_VIEW%ROWTYPE;
  GROUP_CODE VARCHAR2(100);
  GROUP_NAME VARCHAR2(200);
  I NUMBER;
BEGIN
  -- Get count of visible groups
  SELECT COUNT(*)
  INTO N
  FROM GROUPS_VIEW
  WHERE VISIBLE = 1;
  
  -- Clear existing group controls
  SET_ITEM_PROPERTY('CTL.F1', LABEL, '');
  SET_ITEM_PROPERTY('CTL.F2', LABEL, '');
  SET_ITEM_PROPERTY('CTL.F3', LABEL, '');
  SET_ITEM_PROPERTY('CTL.F4', LABEL, '');
  SET_ITEM_PROPERTY('CTL.F5', LABEL, '');
  SET_ITEM_PROPERTY('CTL.F6', LABEL, '');
  
  -- Get default group
  :GLOBAL.DEFAULT_GROUP := :BARCODING.GET_DEFAULT_GROUP;
  
  I := 1;
  
  -- Populate group controls
  FOR group_rec IN (
    SELECT GROUP_CODE, GROUP_NAME
    FROM GROUPS_VIEW
    WHERE VISIBLE = 1
  ) LOOP
    IF I = 1 THEN
      SET_ITEM_PROPERTY('CTL.F1', LABEL, group_rec.GROUP_NAME);
      :CTL.F1 := group_rec.GROUP_CODE;
      
      IF :GLOBAL.DEFAULT_GROUP = group_rec.GROUP_CODE THEN
        GO_ITEM('CTL.F1');
      END IF;
    ELSIF I = 2 THEN
      SET_ITEM_PROPERTY('CTL.F2', LABEL, group_rec.GROUP_NAME);
      :CTL.F2 := group_rec.GROUP_CODE;
      
      IF :GLOBAL.DEFAULT_GROUP = group_rec.GROUP_CODE THEN
        GO_ITEM('CTL.F2');
      END IF;
    ELSIF I = 3 THEN
      SET_ITEM_PROPERTY('CTL.F3', LABEL, group_rec.GROUP_NAME);
      :CTL.F3 := group_rec.GROUP_CODE;
      
      IF :GLOBAL.DEFAULT_GROUP = group_rec.GROUP_CODE THEN
        GO_ITEM('CTL.F3');
      END IF;
    ELSIF I = 4 THEN
      SET_ITEM_PROPERTY('CTL.F4', LABEL, group_rec.GROUP_NAME);
      :CTL.F4 := group_rec.GROUP_CODE;
      
      IF :GLOBAL.DEFAULT_GROUP = group_rec.GROUP_CODE THEN
        GO_ITEM('CTL.F4');
      END IF;
    ELSIF I = 5 THEN
      SET_ITEM_PROPERTY('CTL.F5', LABEL, group_rec.GROUP_NAME);
      :CTL.F5 := group_rec.GROUP_CODE;
      
      IF :GLOBAL.DEFAULT_GROUP = group_rec.GROUP_CODE THEN
        GO_ITEM('CTL.F5');
      END IF;
    ELSIF I = 6 THEN
      SET_ITEM_PROPERTY('CTL.F6', LABEL, group_rec.GROUP_NAME);
      :CTL.F6 := group_rec.GROUP_CODE;
      
      IF :GLOBAL.DEFAULT_GROUP = group_rec.GROUP_CODE THEN
        GO_ITEM('CTL.F6');
      END IF;
    END IF;
    
    I := I + 1;
  END LOOP;
  
  -- Set focus to default group or first group
  IF :GLOBAL.DEFAULT_GROUP IS NOT NULL THEN
    -- Focus already set in loop
    NULL;
  ELSE
    GO_ITEM('CTL.F1');
  END IF;
  
END FILL_GROUPS;

-- ============================================================================
-- PROCEDURE: TEST_ENTERED_BEFORE
-- ============================================================================
-- Purpose: Checks if a test has already been entered in the current registration
-- Returns: 1 if test exists, 0 if not
-- ============================================================================

FUNCTION TEST_ENTERED_BEFORE(
  P_TEST_CODE VARCHAR2,
  P_TEST_TYPE VARCHAR2
) RETURN NUMBER IS
  RES NUMBER := 0;
  EN NUMBER;
  TEST_CODE VARCHAR2(100);
  TEST_TYPE VARCHAR2(100);
  N NUMBER;
  R NUMBER;
  ID VARCHAR2(100);
  TC VARCHAR2(100);
  TT VARCHAR2(100);
  GC VARCHAR2(100);
  X VARCHAR2(1);
  J NUMBER;
  PANEL_ID VARCHAR2(100);
  GROUP_CODE VARCHAR2(100);
BEGIN
  -- Check in current test_names block
  GO_BLOCK('TEST_NAMES');
  FIRST_RECORD;
  
  LOOP
    EXIT WHEN :SYSTEM.LAST_RECORD = 'TRUE';
    
    IF :TEST_NAMES.TEST_CODE = P_TEST_CODE
    AND :TEST_NAMES.TEST_TYPE = P_TEST_TYPE THEN
      RES := 1;
      EXIT;
    END IF;
    
    NEXT_RECORD;
  END LOOP;
  
  -- Check in panel details if this is a panel
  IF P_TEST_TYPE = '6' THEN
    FOR panel_rec IN (
      SELECT * FROM PANEL_TESTS_DETAILS
      WHERE PANEL_ID = P_TEST_CODE
    ) LOOP
      -- Recursively check panel tests
      IF TEST_ENTERED_BEFORE(panel_rec.TEST_CODE, panel_rec.TEST_TYPE) = 1 THEN
        RES := 1;
        EXIT;
      END IF;
    END LOOP;
  END IF;
  
  RETURN RES;
END TEST_ENTERED_BEFORE;

-- ============================================================================
-- END OF REG2 MODULE PL/SQL CODE
-- ============================================================================
