#!/bin/sh

ack -h u:: | perl -pe '@x = m/u::\w+/g; $_ = join ("\n", @x) . "\n" ;' | sort | uniq
