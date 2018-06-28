#!/bin/bash
# Rsync copy to backup files
#
/usr/bin/rsync -avuz /cygdrive/d/"My Documents"/ /cygdrive/h
/usr/bin/rsync -avuz /cygdrive/e/Pictures/ /cygdrive/h/"My Documents"
