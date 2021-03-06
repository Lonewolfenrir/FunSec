#!/usr/bin/env python3


# FunSec - Fungal Secreted Proteins (or Secretome) Prediction Pipeline.
# Copyright (C) 2019 João Baptista <baptista.joao33@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.


from sys import argv


def main():
    try:
        with open(argv[1], "r") as f:
            if str(f.read(1)) == ">":
                f.seek(0)
            else:
                print("ERROR")
                exit(1)
            for line in f:
                line = line.rstrip()
                if line.startswith(">"):
                    if len(line) > 21:
                        print("ERROR1")
                        exit(1)
                    elif " " in line:
                        print("ERROR2")
                        exit(1)
                else:
                    for c in line:
                        if c.upper() not in "ACDEFGHIKLMNPQRSTVWYX":
                            print("ERROR3")
                            exit(1)
    except UnicodeDecodeError:
        print("ERROR")


if __name__ == "__main__":
    main()
