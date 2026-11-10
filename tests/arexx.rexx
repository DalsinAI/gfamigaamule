/* arexx.rexx: aMule's ARexx port (AMULE.1). Start aMule first, with
 * RexxMast running. Prints PASS or FAIL for each check, then QUITs it and
 * checks that the port has gone. rx tests/arexx.rexx
 * Copyright (c) 2026 AmiCradle Team */
OPTIONS RESULTS
PARSE ARG dummy
bad = 0
IF ~SHOW('P', 'AMULE.1') THEN DO
    SAY 'FAIL aMule is not running (no AMULE.1)'
    EXIT 20
END
ADDRESS 'AMULE.1'

'VERSION'
CALL check 'VERSION', rc = 0 & POS('aMule ', result) = 1
'HELP'
CALL check 'HELP', rc = 0 & POS('QUIT', result) > 0 & POS('ADDLINK', result) > 0 & POS('CONNECT', result) > 0 & POS('DISCONNECT', result) > 0 & POS('STATUS', result) > 0
'FAULT 205'
CALL check 'FAULT', rc = 0 & result ~= ''
'NOSUCH'
CALL check 'unknown command', rc = 20
'DEACTIVATE'
CALL check 'DEACTIVATE', rc = 0
'ACTIVATE'
CALL check 'ACTIVATE', rc = 0
'STATUS'
CALL check 'STATUS', rc = 0 & WORDS(result) = 2
'ADDLINK "not-a-link"'
CALL check 'ADDLINK bad link', rc = 10
'DISCONNECT'
CALL check 'DISCONNECT', rc = 0
'QUIT'
CALL check 'QUIT', rc = 0
DO i = 1 TO 30
    IF ~SHOW('P', 'AMULE.1') THEN LEAVE
    ADDRESS COMMAND 'Wait 1'
END
CALL check 'port gone after QUIT', ~SHOW('P', 'AMULE.1')
IF bad = 0 THEN SAY 'amule arexx: ALL PASS'
ELSE SAY 'amule arexx:' bad 'FAILED'
EXIT bad

check: PARSE ARG what, ok
IF ok THEN SAY 'PASS' what
ELSE DO
    SAY 'FAIL' what '(rc' rc')'
    bad = bad + 1
END
RETURN
