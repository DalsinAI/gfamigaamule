/* Status.rexx: aMule connects and says how it stands.
   rx Status.rexx   (aMule running) */
OPTIONS RESULTS
IF ~SHOW('P', 'AMULE.1') THEN DO
    SAY 'aMule is not running.'
    EXIT 5
END
ADDRESS 'AMULE.1'
'CONNECT'
ADDRESS COMMAND 'Wait 5'
'STATUS'
SAY RESULT
