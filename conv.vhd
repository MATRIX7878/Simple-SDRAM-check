LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY conv IS
    PORT(clk : IN STD_LOGIC; -- Kept in port list for entity compatibility, but unused
         char : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
         hund, tens, ones, hexLow, hexHigh : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
        );
END ENTITY;

ARCHITECTURE behavior OF conv IS
BEGIN
    PROCESS(char)
        VARIABLE val : INTEGER;
        VARIABLE h, t, o : INTEGER;
    BEGIN
        val := TO_INTEGER(UNSIGNED(char));
        
        -- Decimal digit extraction
        h := val / 100;
        t := (val / 10) MOD 10;
        o := val MOD 10;
        
        hund <= STD_LOGIC_VECTOR(TO_UNSIGNED(48 + h, 8));
        tens <= STD_LOGIC_VECTOR(TO_UNSIGNED(48 + t, 8));
        ones <= STD_LOGIC_VECTOR(TO_UNSIGNED(48 + o, 8));
        
        -- Hex conversion (High Nibble)
        IF UNSIGNED(char(7 DOWNTO 4)) <= 9 THEN
            hexHigh <= STD_LOGIC_VECTOR(TO_UNSIGNED(48 + TO_INTEGER(UNSIGNED(char(7 DOWNTO 4))), 8));
        ELSE
            hexHigh <= STD_LOGIC_VECTOR(TO_UNSIGNED(55 + TO_INTEGER(UNSIGNED(char(7 DOWNTO 4))), 8));
        END IF;

        -- Hex conversion (Low Nibble)
        IF UNSIGNED(char(3 DOWNTO 0)) <= 9 THEN
            hexLow <= STD_LOGIC_VECTOR(TO_UNSIGNED(48 + TO_INTEGER(UNSIGNED(char(3 DOWNTO 0))), 8));
        ELSE
            hexLow <= STD_LOGIC_VECTOR(TO_UNSIGNED(55 + TO_INTEGER(UNSIGNED(char(3 DOWNTO 0))), 8));
        END IF;
    END PROCESS;
END ARCHITECTURE;