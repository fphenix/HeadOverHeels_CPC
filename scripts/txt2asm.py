# This converts the "fileinfo_II.txt" file into a compilable z80 asm (Maxam compatible) file.
# Change location of "infile" appropriatly

import re

from os.path import dirname, realpath, join

cwd = dirname(realpath(__file__))

#---------------------------------------------------------------------------------------------------
infile = join(cwd, "..", "dsk", "Headover_DSK", "fileinfo_II.txt")
outfile = join(cwd, "fileinfo_II_________.z80")

emptyln_pattern = re.compile(r"^\s*$")
copyln_pattern = re.compile(r"(^\s*((;;)|(\.)|(org)|([^\s]+:))).*$")
asmln_pattern = re.compile(r"(^\s+[\dABCDEF]{4}\s+(?:[\dABCDEF]{2}\s+)*)")

with open(outfile, 'w') as fw:
    with open(infile, 'r') as fr:
        for line in fr:
            if emptyln_pattern.match(line):
                fw.write("\n")
            elif copyln_pattern.match(line):
                fw.write(line)
            else:
                fw.write(asmln_pattern.sub("\t", line))

raise SystemExit
