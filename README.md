# Remove-JNDILookup
Powershell script to remove the JNDI Lookup class from JAR files

This code comes with NO WARRANTY. It's just an example.

Vendors were telling me to find each JAR file that had JNDILookup.class, back it up, rename it to .ZIP, open it, find the JNDILookup.class, delete that file, close the ZIP, rename it back to JAR.

I figured a Powershell script could do it in one shot.

Note this does NOT dive into WAR Files or ZIPs looking for enclosed JAR files.
