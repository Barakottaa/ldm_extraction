-- Extracted SQL from R_FEES
-- 1. Messages and System Tables
SELECT DISPLAY_OPTION,
    DECODE(DISPLAY_LANG, 'E', E_DISPLAY_TEXT, 'A', DISPLAY_TEXT),
    DISPLAY_TYPE,
    SHOW_DEFAULT
FROM MESSAGES
WHERE MESS_CODE = :m
    AND MESS_LEVEL = 'E'
    AND DB_CODE = :v
    AND (
        DISPLAY_MODE = :system.mode
        OR DISPLAY_MODE = 'BOTH'
    );
SELECT SYSTEM_MESSAGES
FROM SYSTEM_TABLE_SEC;
SELECT DISPLAY_OPTION,
    DECODE(DISPLAY_LANG, 'E', E_DISPLAY_TEXT, 'A', DISPLAY_TEXT),
    DISPLAY_TYPE,
    SHOW_DEFAULT
FROM MESSAGES
WHERE MESS_CODE = :m
    AND MESS_LEVEL = 'M'
    AND DB_CODE = :v
    AND (
        DISPLAY_MODE = :system.mode
        OR DISPLAY_MODE = 'BOTH'
    );
SELECT DISPLAY_TITLE D
FROM SYSTEM_TABLE_SEC;
SELECT OBJECT_NAME N
FROM OBJECTS
WHERE UPPER(OBJECT_PATH) = UPPER(:v);
-- 2. Privileges
SELECT OBJECT_ID
FROM OBJECTS
WHERE UPPER(OBJECT_PATH) = UPPER(:n);
SELECT *
FROM USER_PRIVILEGE
WHERE USER_ID = :global.user_id
    AND OBJECT_ID = :o;
SELECT USER_GROUP
FROM USERS
WHERE USER_ID = :global.user_id;
SELECT *
FROM GROUP_PRIVILEGE
WHERE GROUP_ID = :gi
    AND OBJECT_ID = :o;
SELECT USE_RIGHTS R,
    USE_SECURITY S
FROM SYSTEM_TABLE_SEC;
-- 3. Groups and Tests
SELECT DISTINCT GLOBAL_TESTS.GROUP_CODE,
    GROUPS.GROUP_NAME,
    NULL N,
    NULL N1,
    NULL N2
FROM GLOBAL_TESTS,
    GROUPS_VIEW GROUPS
WHERE GROUPS.GROUP_CODE = GLOBAL_TESTS.GROUP_CODE
ORDER BY 2;
SELECT ALL GLOBAL_TESTS.TEST_CODE,
    GLOBAL_TESTS.TEST_NAME,
    GLOBAL_TESTS.TEST_TYPE,
    GROUPS.GROUP_CODE
FROM GLOBAL_TESTS,
    GROUPS
WHERE GROUPS.GROUP_CODE = GLOBAL_TESTS.GROUP_CODE
    AND (
        GROUPS.GROUP_CODE = :rank_fees.group_code
        OR :rank_fees.group_code IS NULL
    )
ORDER BY 2;
-- 4. Test Fees
SELECT T.GROUP_CODE,
    GROUP_NAME,
    TEST_CODE,
    TEST_NAME,
    TEST_TYPE
FROM TEST_FEES T,
    GROUPS G
WHERE T.GROUP_CODE = G.GROUP_CODE
ORDER BY UPPER(GROUP_NAME),
    UPPER(TEST_NAME);
SELECT T.GROUP_CODE,
    GROUP_NAME,
    TEST_CODE,
    TEST_NAME,
    TEST_TYPE
FROM GLOBAL_TESTS T,
    GROUPS_VIEW G
WHERE T.GROUP_CODE = G.GROUP_CODE
ORDER BY UPPER(GROUP_NAME),
    UPPER(TEST_NAME);
-- 5. Ranks
SELECT COUNT(*)
FROM RANKS
WHERE UPPER(:rank_name) = UPPER(RANK_NAME);
SELECT COUNT(*)
FROM RANKS
WHERE UPPER(:rank_no) = UPPER(RANK_NO)
    AND ROWID <> :ranks.rowid;
SELECT NVL(RANKS_SEQ.NEXTVAL, 1)
FROM DUAL;
-- 6. Rank Fees
SELECT COUNT(*)
FROM RANK_FEES
WHERE RANK_CODE = :relatives.rank_code
    AND RELATIVE_CODE = :relatives.relative_code
    AND TEST_CODE = :s1_rec.test_code
    AND TEST_TYPE = :s1_rec.test_type;
INSERT INTO RANK_FEES (
        RANK_CODE,
        RELATIVE_CODE,
        GROUP_CODE,
        TEST_CODE,
        TEST_TYPE,
        PAID_BY_PATIENT,
        PAID_BY_INSURANCE,
        SER,
        CREATED_BY,
        CREATED_DATE
    )
VALUES (
        :relatives.rank_code,
        :relatives.relative_code,
        :s1_rec.group_code,
        :s1_rec.test_code,
        :s1_rec.test_type,
        0,
        0,
        1,
        :global.user,
        SYSDATE
    );
INSERT INTO RANK_FEES (
        RANK_CODE,
        RELATIVE_CODE,
        GROUP_CODE,
        TEST_CODE,
        TEST_TYPE,
        PAID_BY_PATIENT,
        PAID_BY_INSURANCE,
        SER,
        CREATED_BY,
        CREATED_DATE
    )
SELECT :relatives.rank_code,
    :relatives.relative_code,
    T.GROUP_CODE,
    TEST_CODE,
    TEST_TYPE,
    0,
    0,
    1,
    :global.user,
    SYSDATE
FROM GLOBAL_TESTS T;
-- 7. Relatives
SELECT 1
FROM RELATIVES R
WHERE R.RANK_CODE = :RANKS.RANK_CODE;
SELECT COUNT(*)
FROM RELATIVES
WHERE UPPER(:relative_name) = UPPER(RELATIVE_NAME)
    AND :relatives.rank_code = RANK_CODE;
SELECT COUNT(*)
FROM RELATIVES
WHERE UPPER(:relative_no) = UPPER(RELATIVE_NO)
    AND RANK_CODE = :ranks.rank_code
    AND ROWID <> :relatives.rowid;
SELECT NVL(RELATIVES_SEQ.NEXTVAL, 1)
FROM DUAL;
SELECT COUNT(*)
FROM RELATIVES
WHERE UPPER(:relative_name) = UPPER(RELATIVE_NAME)
    AND :relatives.rank_code = RANK_CODE
    AND VISIBLE = :relatives.visible
    AND ROWID <> :relatives.rowid;
-- 8. Price List Restoration Logic (PL/SQL Blocks)
SELECT *
FROM RANK_PRICE_LIST
WHERE RANK_CODE = :ranks.rank_code
    AND RELATIVE_CODE = :relatives.relative_code;
-- Primary Patient Update
UPDATE RANK_FEES RF
SET PAID_BY_PATIENT = (
        SELECT ROUND(
                OPR(
                    PATIENT_FEE,
                    :c_rec.pri_pat_fee_opr,
                    :c_rec.pri_pat_fee_factor
                ),
                :c_rec.approximate_prices
            )
        FROM PRICE_LIST_DET PD
        WHERE PD.PRICE_LIST_CODE = :c_rec.pri_pat_price_list
            AND PD.TEST_CODE = RF.TEST_CODE
            AND PD.TEST_TYPE = RF.TEST_TYPE
    )
WHERE RANK_CODE = :c_rec.rank_code
    AND RELATIVE_CODE = :c_rec.relative_code
    AND EXISTS (
        SELECT 'X'
        FROM PRICE_LIST_DET PL
        WHERE PL.PRICE_LIST_CODE = :c_rec.pri_pat_price_list
            AND PL.TEST_CODE = RF.TEST_CODE
            AND PL.TEST_TYPE = RF.TEST_TYPE
            AND ACTIVE = 1
            AND PL.PATIENT_FEE <> 0
    )
    AND MAIN_PRICE_LIST_EXCLUDE = 2;
-- Primary Patient Insert
INSERT INTO RANK_FEES (
        RANK_CODE,
        RELATIVE_CODE,
        GROUP_CODE,
        TEST_CODE,
        TEST_TYPE,
        PAID_BY_PATIENT,
        PAID_BY_INSURANCE,
        SER,
        CREATED_BY,
        CREATED_DATE
    )
SELECT :c_rec.rank_code,
    :c_rec.relative_code,
    T.GROUP_CODE,
    TEST_CODE,
    TEST_TYPE,
    ROUND(
        OPR(
            PATIENT_FEE,
            :c_rec.pri_pat_fee_opr,
            :c_rec.pri_pat_fee_factor
        ),
        :c_rec.approximate_prices
    ),
    0,
    1,
    :global.user,
    SYSDATE
FROM PRICE_LIST_DET T
WHERE PRICE_LIST_CODE = :c_rec.pri_pat_price_list
    AND NOT EXISTS (
        SELECT 'X'
        FROM RANK_FEES PL
        WHERE PL.RANK_CODE = :c_rec.rank_code
            AND PL.RELATIVE_CODE = :c_rec.relative_code
            AND PL.TEST_CODE = T.TEST_CODE
            AND PL.TEST_TYPE = T.TEST_TYPE
    );
-- Primary Insurance Update
UPDATE RANK_FEES RF
SET PAID_BY_INSURANCE = (
        SELECT ROUND(
                OPR(
                    PATIENT_FEE,
                    :c_rec.pri_insur_fee_opr,
                    :c_rec.pri_insur_fee_factor
                ),
                :c_rec.approximate_prices
            )
        FROM PRICE_LIST_DET PD
        WHERE PD.PRICE_LIST_CODE = :c_rec.pri_insur_price_list
            AND PD.TEST_CODE = RF.TEST_CODE
            AND PD.TEST_TYPE = RF.TEST_TYPE
    )
WHERE RANK_CODE = :c_rec.rank_code
    AND RELATIVE_CODE = :c_rec.relative_code
    AND EXISTS (
        SELECT 'X'
        FROM PRICE_LIST_DET PL
        WHERE PL.PRICE_LIST_CODE = :c_rec.pri_insur_price_list
            AND PL.TEST_CODE = RF.TEST_CODE
            AND PL.TEST_TYPE = RF.TEST_TYPE
            AND ACTIVE = 1
            AND PL.PATIENT_FEE <> 0
    )
    AND MAIN_PRICE_LIST_EXCLUDE = 2;
-- Primary Insurance Insert
INSERT INTO RANK_FEES (
        RANK_CODE,
        RELATIVE_CODE,
        GROUP_CODE,
        TEST_CODE,
        TEST_TYPE,
        PAID_BY_PATIENT,
        PAID_BY_INSURANCE,
        SER,
        CREATED_BY,
        CREATED_DATE
    )
SELECT :c_rec.rank_code,
    :c_rec.relative_code,
    T.GROUP_CODE,
    TEST_CODE,
    TEST_TYPE,
    0,
    ROUND(
        OPR(
            PATIENT_FEE,
            :c_rec.pri_insur_fee_opr,
            :c_rec.pri_insur_fee_factor
        ),
        :c_rec.approximate_prices
    ),
    1,
    :global.user,
    SYSDATE
FROM PRICE_LIST_DET T
WHERE PRICE_LIST_CODE = :c_rec.pri_insur_price_list
    AND NOT EXISTS (
        SELECT 'X'
        FROM RANK_FEES PL
        WHERE PL.RANK_CODE = :c_rec.rank_code
            AND PL.RELATIVE_CODE = :c_rec.relative_code
            AND PL.TEST_CODE = T.TEST_CODE
            AND PL.TEST_TYPE = T.TEST_TYPE
    );
-- Secondary Patient Update
UPDATE RANK_FEES RF
SET PAID_BY_PATIENT = (
        SELECT ROUND(
                OPR(
                    PATIENT_FEE,
                    :c_rec.sec_pat_fee_opr,
                    :c_rec.sec_pat_fee_factor
                ),
                :c_rec.approximate_prices
            )
        FROM PRICE_LIST_DET PD
        WHERE PD.PRICE_LIST_CODE = :c_rec.sec_pat_price_list
            AND PD.TEST_CODE = RF.TEST_CODE
            AND PD.TEST_TYPE = RF.TEST_TYPE
    )
WHERE RANK_CODE = :c_rec.rank_code
    AND RELATIVE_CODE = :c_rec.relative_code
    AND EXISTS (
        SELECT 'X'
        FROM PRICE_LIST_DET PL
        WHERE PL.PRICE_LIST_CODE = :c_rec.pri_pat_price_list
            AND PL.TEST_CODE = RF.TEST_CODE
            AND PL.TEST_TYPE = RF.TEST_TYPE
            AND ACTIVE <> 1
    )
    AND EXISTS (
        SELECT 'X'
        FROM PRICE_LIST_DET PL2
        WHERE PL2.PRICE_LIST_CODE = :c_rec.sec_pat_price_list
            AND PL2.TEST_CODE = RF.TEST_CODE
            AND PL2.TEST_TYPE = RF.TEST_TYPE
            AND ACTIVE = 1
            AND PL2.PATIENT_FEE <> 0
    )
    AND MAIN_PRICE_LIST_EXCLUDE = 2;
-- Secondary Patient Insert
INSERT INTO RANK_FEES (
        RANK_CODE,
        RELATIVE_CODE,
        GROUP_CODE,
        TEST_CODE,
        TEST_TYPE,
        PAID_BY_PATIENT,
        PAID_BY_INSURANCE,
        SER,
        CREATED_BY,
        CREATED_DATE
    )
SELECT :c_rec.rank_code,
    :c_rec.relative_code,
    T.GROUP_CODE,
    TEST_CODE,
    TEST_TYPE,
    ROUND(
        OPR(
            PATIENT_FEE,
            :c_rec.sec_pat_fee_opr,
            :c_rec.sec_pat_fee_factor
        ),
        :c_rec.approximate_prices
    ),
    0,
    1,
    :global.user,
    SYSDATE
FROM PRICE_LIST_DET T
WHERE PRICE_LIST_CODE = :c_rec.sec_pat_price_list
    AND NOT EXISTS (
        SELECT 'X'
        FROM RANK_FEES PL
        WHERE PL.RANK_CODE = :c_rec.rank_code
            AND PL.RELATIVE_CODE = :c_rec.relative_code
            AND PL.TEST_CODE = T.TEST_CODE
            AND PL.TEST_TYPE = T.TEST_TYPE
    );
-- Secondary Insurance Update
UPDATE RANK_FEES RF
SET PAID_BY_INSURANCE = (
        SELECT ROUND(
                OPR(
                    PATIENT_FEE,
                    :c_rec.sec_insur_fee_opr,
                    :c_rec.sec_insur_fee_factor
                ),
                :c_rec.approximate_prices
            )
        FROM PRICE_LIST_DET PD
        WHERE PD.PRICE_LIST_CODE = :c_rec.sec_insur_price_list
            AND PD.TEST_CODE = RF.TEST_CODE
            AND PD.TEST_TYPE = RF.TEST_TYPE
    )
WHERE RANK_CODE = :c_rec.rank_code
    AND RELATIVE_CODE = :c_rec.relative_code
    AND EXISTS (
        SELECT 'X'
        FROM PRICE_LIST_DET PL
        WHERE PL.PRICE_LIST_CODE = :c_rec.pri_insur_price_list
            AND PL.TEST_CODE = RF.TEST_CODE
            AND PL.TEST_TYPE = RF.TEST_TYPE
            AND ACTIVE <> 1
    )
    AND EXISTS (
        SELECT 'X'
        FROM PRICE_LIST_DET PL2
        WHERE PL2.PRICE_LIST_CODE = :c_rec.sec_insur_price_list
            AND PL2.TEST_CODE = RF.TEST_CODE
            AND PL2.TEST_TYPE = RF.TEST_TYPE
            AND ACTIVE = 1
            AND PL2.PATIENT_FEE <> 0
    )
    AND MAIN_PRICE_LIST_EXCLUDE = 2;
-- Secondary Insurance Insert
INSERT INTO RANK_FEES (
        RANK_CODE,
        RELATIVE_CODE,
        GROUP_CODE,
        TEST_CODE,
        TEST_TYPE,
        PAID_BY_PATIENT,
        PAID_BY_INSURANCE,
        SER,
        CREATED_BY,
        CREATED_DATE
    )
SELECT :c_rec.rank_code,
    :c_rec.relative_code,
    T.GROUP_CODE,
    TEST_CODE,
    TEST_TYPE,
    0,
    ROUND(
        OPR(
            PATIENT_FEE,
            :c_rec.sec_insur_fee_opr,
            :c_rec.sec_insur_fee_factor
        ),
        :c_rec.approximate_prices
    ),
    1,
    :global.user,
    SYSDATE
FROM PRICE_LIST_DET T
WHERE PRICE_LIST_CODE = :c_rec.sec_insur_price_list
    AND NOT EXISTS (
        SELECT 'X'
        FROM RANK_FEES PL
        WHERE PL.RANK_CODE = :c_rec.rank_code
            AND PL.RELATIVE_CODE = :c_rec.relative_code
            AND PL.TEST_CODE = T.TEST_CODE
            AND PL.TEST_TYPE = T.TEST_TYPE
    );