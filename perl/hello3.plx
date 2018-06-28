#!/usr/bin/perl
use warnings;

{
	print "Hello, workd. \n";
	print "This is a second message.\n";
	{
		print "This is another message, but in a different script paragraph!\n";
	}
	print "This is back in the original paragraph. \t";
}
print "I have closed the last paragraph";

print "This is a UNICODE Hexidecimal output, \/x####\n";
print "\x{2620}"
