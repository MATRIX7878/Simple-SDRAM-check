LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY top IS
	PORT(clk : IN STD_LOGIC;
		  RST : IN STD_LOGIC;
--		  RX : IN STD_LOGIC;
--		  LED : OUT STD_LOGIC := '0';
		  TX : OUT STD_LOGIC;
		  CKE : OUT STD_LOGIC;
		  SDRAM_CLK : OUT STD_LOGIC;
		  NCS : OUT STD_LOGIC;
		  NWE : OUT STD_LOGIC;
		  NRAS : OUT STD_LOGIC;
		  NCAS : OUT STD_LOGIC;
		  ADDR : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
		  BA : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		  DQML : INOUT STD_LOGIC;
		  DQMU : INOUT STD_LOGIC;
		  DQ : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
		  );
END ENTITY;

ARCHITECTURE behavior OF top IS
TYPE state IS (IDLE, PERIOD, NOP, NOPWR, NOPR, PRECHARGE, AUTOREF, MRS, ACTIVE, WRITE, READ, DONE);
SIGNAL currentState, returnState : state := IDLE;

SIGNAL locked : STD_LOGIC := '0';
SIGNAL OCLK : STD_LOGIC;

SIGNAL cycle : INTEGER RANGE 0 TO 8 := 0;
SIGNAL cycles : INTEGER RANGE 0 TO 8 := 0;
SIGNAL count : INTEGER RANGE 0 TO 13335 := 0;
SIGNAL counter : INTEGER RANGE 0 TO 13335 := 0;
SIGNAL test : INTEGER RANGE 0 TO 131073 := 0;

SIGNAL rx_data : STD_LOGIC_VECTOR (7 DOWNTO 0);
--SIGNAL rx_valid : STD_LOGIC;
--SIGNAL rx_ready : STD_LOGIC;

SIGNAL tx_data, tx_str, tx_in, tx_asc, tx_hex : STD_LOGIC_VECTOR (7 DOWNTO 0);
SIGNAL tx_ready : STD_LOGIC;
SIGNAL tx_valid : STD_LOGIC;

--SIGNAL HUND, TENS, ONES : STD_LOGIC_VECTOR (7 DOWNTO 0);
--SIGNAL HEXLOW, HEXHIGH : STD_LOGIC_VECTOR (7 DOWNTO 0);

SIGNAL str : STRING (1 TO 128);
SIGNAL mode : INTEGER RANGE 0 TO 128 := 0;

SIGNAL start : STD_LOGIC := '0';
SIGNAL busy : STD_LOGIC := '0';

SIGNAL parse : STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0');

COMPONENT PLL IS
	PORT(
		refclk   : IN  STD_LOGIC := '0'; --  refclk.clk
		rst      : IN  STD_LOGIC := '0'; --   reset.reset
		outclk_0 : OUT STD_LOGIC;        -- outclk0.clk
		locked   : OUT STD_LOGIC         --  locked.export
	);
END COMPONENT PLL;

--COMPONENT UART_RX IS
--    PORT(clk : IN STD_LOGIC;
--         reset : IN STD_LOGIC;
--         rx_IN : IN STD_LOGIC;
--         rx_valid : OUT STD_LOGIC;
--         rx_data : OUT STD_LOGIC_VECTOR (7 downto 0)
--         );
--END COMPONENT;

COMPONENT UART_TX IS
    PORT (clk : IN STD_LOGIC;
          reset : IN STD_LOGIC;
          tx_valid : IN STD_LOGIC;
          tx_data : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
          tx_ready : OUT STD_LOGIC;
          tx_OUT : OUT STD_LOGIC);
END COMPONENT;

--COMPONENT conv IS
--    PORT(clk : IN STD_LOGIC;
--         char : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
--         hund, tens, ones, hexLow, hexHigh : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
--        );
--END COMPONENT;

COMPONENT printer IS
    PORT(clk : IN STD_LOGIC;
         a : IN STRING;
         b : IN INTEGER;
         start : IN STD_LOGIC;
         busy : OUT STD_LOGIC;
         tx_ready : IN STD_LOGIC;
         tx_valid : OUT STD_LOGIC;
         tx_data : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
        );
END COMPONENT;

FUNCTION TO_CHAR(char : STD_LOGIC_VECTOR(7 DOWNTO 0)) RETURN CHARACTER IS
    BEGIN
        RETURN CHARACTER'VAL(TO_INTEGER(UNSIGNED(char)));
END FUNCTION;

BEGIN
	SDRAM_CLK <= OCLK;
	DQ <= STD_LOGIC_VECTOR(TO_UNSIGNED(test, 16)) WHEN (currentState = WRITE or currentState = NOPWR) ELSE (OTHERS => 'Z');

	PROCESS(ALL)
	BEGIN
		IF NOT RST THEN
			currentState <= IDLE;
			returnState <= IDLE;
			cycle <= 0;
			cycles <= 0;
			count <= 0;
			counter <= 0;
			test <= 0;
			CKE <= '0';
			NCS <= '1';
			NWE <= '1';
			NRAS <= '1';
			NCAS <= '1';
			ADDR <= (OTHERS => '0');
			BA <= (OTHERS => '0');
			DQML <= '0';
			DQMU <= '0';
		ELSIF RISING_EDGE(OCLK) THEN
			IF locked THEN
				CASE currentState IS
				WHEN PERIOD => IF counter = count THEN
					counter <= 0;
					currentState <= returnState;
				ELSE
					counter <= counter + 1;
				END IF;
				WHEN NOP => CKE <= '1';
					NCS <= '0';
					NRAS <= '1';
					NCAS <= '1';
					NWE <= '1';
					currentState <= PERIOD;
				WHEN NOPWR => count <= 0;
					IF test = 1023 THEN
						NWE <= '0';
						NCAS <= '1';
						test <= 0;
						currentState <= NOP;
						returnState <= READ;
					ELSE
						currentState <= NOP;
						returnState <= NOPWR;
						test <= test + 1;
					END IF;
				WHEN NOPR => count <= 0;
					IF test = 1022 THEN
						NWE <= '0';
						test <= 0;
						currentState <= NOP;
						returnState <= DONE;
					ELSE
						currentState <= NOP;
						returnState <= NOPR;
						test <= test + 1;
					END IF;
				WHEN IDLE => DQML <= '1';
					DQMU <= '1';
					count <= 13334;
					currentState <= NOP;
					returnState <= PRECHARGE;
				WHEN PRECHARGE => NCS <= '0';
					NRAS <= '0';
					NCAS <= '1';
					NWE <= '0';
					ADDR(10) <= '1';
					count <= 2;
					currentState <= PERIOD;
					returnState <= AUTOREF;
				WHEN AUTOREF => NCS <= '0';
					NRAS <= '0';
					NCAS <= '0';
					NWE <= '1';
					cycle <= 8;
					count <= 8;
					currentState <= NOP;
					IF cycles /= cycle THEN
						cycles <= cycles + 1;
						returnState <= AUTOREF;
					ELSE
						returnState <= MRS;
						cycles <= 0;
					END IF;
				WHEN MRS => NCS <= '0';
					NRAS <= '0';
					NCAS <= '0';
					NWE <= '0';
					BA(0) <= '0';
					BA(1) <= '0';
					ADDR(0) <= '1';
					ADDR(1) <= '1';
					ADDR(2) <= '1';
					ADDR(3) <= '0';
					ADDR(4) <= '0';
					ADDR(5) <= '1';
					ADDR(6) <= '0';
					ADDR(7) <= '0';
					ADDR(8) <= '0';
					ADDR(9) <= '0';
					ADDR(10) <= '0';
					ADDR(11) <= '0';
					ADDR(12) <= '0';
					count <= 2;
					currentState <= NOP;
					returnState <= ACTIVE;
				WHEN ACTIVE => NCS <= '0';
					NRAS <= '0';
					NCAS <= '1';
					NWE <= '1';
					count <= 2;
					BA(1 DOWNTO 0) <= (OTHERS => '0');
					ADDR(12 DOWNTO 0) <= (OTHERS => '0');
					currentState <= NOP;
					returnState <= WRITE;
				WHEN WRITE => NCS <= '0';
					NRAS <= '1';
					NCAS <= '0';
					NWE <= '0';
					BA(1 DOWNTO 0) <= (OTHERS => '0');
					ADDR(10) <= '0';
					ADDR(9 DOWNTO 0) <= (OTHERS => '0');
					DQML <= '0';
					DQMU <= '0';
					currentState <= NOPWR;
				WHEN READ => NCS <= '0';
					NRAS <= '1';
					NCAS <= '0';
					NWE <= '1';
					BA(1 DOWNTO 0) <= (OTHERS => '0');
					ADDR(10) <= '0';
					ADDR(9 DOWNTO 0) <= (OTHERS => '0');
					count <= 0;
					currentState <= NOP;
					returnState <= NOPR;
				WHEN DONE => CKE <= '1';
					NCS <= '0';
					NRAS <= '1';
					NCAS <= '1';
					NWE <= '1';
				END CASE;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(ALL)
	BEGIN
		IF RISING_EDGE(OCLK) THEN
			IF currentState = NOP THEN
				start <= '0';
			END IF;
			IF currentState = WRITE THEN
				str <= "Writing to chip" & CR & LF & (1 TO 111 => NUL);
				mode <= 0;
				start <= '1';
			END IF;
			IF currentState = NOPR THEN
				parse <= STD_LOGIC_VECTOR(UNSIGNED(parse) + 1);
				IF parse /= DQ THEN
					str <= TO_CHAR(parse(15 DOWNTO 8)) & TO_CHAR(parse(7 DOWNTO 0)) & CR & LF & (1 TO 124 => NUL);
					mode <= 0;
					start <= '1';
				ELSE
					str <= "Read good" & CR & LF & (1 TO 117 => NUL);
					mode <= 0;
					start <= '1';
				END IF;
			END IF;
		END IF;
	END PROCESS;

clock: PLL PORT MAP(refclk => clk, rst => '0', outclk_0 => OCLK, locked => locked);
--uartrx : UART_RX PORT MAP (clk => clk, reset => RST, rx_IN => RX, rx_valid => rx_valid, rx_data => rx_data);
uarttx : UART_TX PORT MAP (clk => OCLK, reset => RST, tx_valid => tx_valid, tx_data => tx_data, tx_ready => tx_ready, tx_OUT => TX);
--change : conv PORT MAP (clk => clk, char => rx_data, hund => HUND, tens => TENS, ones => ONES, hexLow => HEXLOW, hexHigh => HEXHIGH);
print : printer PORT MAP (clk => OCLK, a => str, b => mode, start => start, busy => busy, tx_ready => tx_ready, tx_valid => tx_valid, tx_data => tx_data);
END ARCHITECTURE;