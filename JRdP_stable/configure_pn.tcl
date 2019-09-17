#© 2019 CNRS-LAAS

#Author: M’Barek Zacri

#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

#1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

#2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Dependencies
package require vectcl;
namespace import vectcl::*;
package require genomix;
namespace import ::genomix::*;

if { $argc != 1 } {
    error "Invalid syntax. Usage:\n
    $argv0 <pn_ndr_file>"
}

# Extract given .ndr file directory and file infos to retrieve
# structure & configuration files attached
set pn_ndr_file [lindex $argv 0]
set working_dir [file dirname $pn_ndr_file]
set ndr_filename [file tail $pn_ndr_file]
set filename_root [file rootname $ndr_filename]
puts "Working directory: $working_dir"
set pn_struct_matrix_tcl_file [file join $working_dir "${filename_root}_struct.tcl"]
set pn_config_tcl_file [file join $working_dir "${filename_root}_config.tcl"]

namespace eval JRdP {
  set cur_path [pwd];
  source $cur_path/src/generate_matrices.tcl;
  source $pn_struct_matrix_tcl_file;
  source $cur_path/src/data.tcl;
  source $cur_path/src/generate_configuration.tcl;
}
