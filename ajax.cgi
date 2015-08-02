<?php
    // This is just a reimplementation of the vulnerable code section in the ajax.cgi binary
	system("sudo bash -c 'ping -c 4 ".$_GET["pip"]."'");
?>
