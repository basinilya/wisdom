rem Create the key with proper letter case
regedit NullSessionShares.reg

rem Set the key value and refresh the policy
secedit /configure /db %temp%\secedit.sdb /cfg NullSessionShares.inf /log %temp%\NullSessionShares.log

pause
