#© 2019 CNRS-LAAS

#Author: M’Barek Zacri

#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

#1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

#2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


namespace eval Generate_matrice {
	puts "Generating Petri net structure martix to file: $pn_struct_matrix_tcl_file..."
	set fd_in_ndr [open $pn_ndr_file r]
	set fd_out_mat [open $pn_struct_matrix_tcl_file w+]
	#Variables:
	set nb_t 0;#nombre de transitions.
	set nb_p 0;#nombre de places.
	set pre ""; #liste contenant des arcs pre  ( arc=liste: "place transition poids" ). Utilisé ensuite pour générer la matrice PRE.
	set post "";#liste contenant des arcs post ( arc=liste: "place transition poids" ). Utilisé ensuite pour générer la matrice POST.
	set mar "";#liste contenant les marquages initials des places ( marquag=liste: "place marquage" ).
	#Lecture ligne par ligne du fichier .ndr:
	#Dans la detection des patterns, les espaces sont considérés.
	while {[gets $fd_in_ndr line] >= 0} {
		#Si la ligne commence par e. Récupération des arcs.Exemple:e p5 0.8573883569 108.853112 t5 0.009084688674 35.05709629 1 n. Cf .ndr
		if { [string index $line 0]== "e" } {
			#Si on detecte un pettern pre de type {p(chiffres==place) (nimporte)t(chiffres==transition) (nimporte)(chiffres==poids) n}
			if { [regexp  { p([0-9]{1,}) .*t([0-9]{1,}) .*([0-9]{1,}) n} $line tout place transition poids] } {
				#Calcul (nb_t-1) : max des transitions:
				if { $nb_t < $transition } { set nb_t $transition }
				#Calcul (nb_p-1) : max des places:
				if { $nb_p < $place } { set nb_p $place }
				#Ajout d'un arc:
				lappend pre [list "$place" "$transition" "$poids"]

			#Si on detecte un pettern post de type {t(chiffres==transition) (nimporte)p(chiffres==place) (nimporte)(chiffres==poids) n}
			} elseif { [regexp  { t([0-9]{1,}) .*p([0-9]{1,}) .*([0-9]{1,}) n} $line tout transition place poids]	} {
				if { $nb_t < $transition } { set nb_t $transition }
				if { $nb_p < $place } { set nb_p $place }
				lappend post [list "$place" "$transition" "$poids"]
			# Sinon : ERROR
			} else {
        error "Invalid NDR file" "Configuration line: \{ $line \} in $pn_ndr_file is not valid"
      }
		#Si la ligne commence par p. Récupération du marquage:
		} elseif { [string index $line 0]== "p" } {
			#Si on detecte un pettern de type {p(chiffres==place) (chiffres==marquage) n}
			if { [regexp { p([0-9]{1,}) ([0-9]{1,}) n} $line tout place marquage] } {
				#Ajout marquage:
				lappend mar [list "$place" "$marquage"]
			}
		}
	}
	#nb_t est le nombre de transitions indexées à partir de 0. Il faut ajouter 1:
	set nb_t [expr $nb_t + 1]
	#de meme:
	set nb_p [expr $nb_p + 1]
	#Variables:
	vexpr {

	 	PRE=zeros(nb_p,nb_t);
		POST=zeros(nb_p,nb_t);
		M=zeros(nb_p,1);

	}
	#Chargement de PRE,POST ET M:
	set len_pre [llength $pre]
	set len_post [llength $post]
	set len_mar [llength $mar]
	if { $len_pre < $nb_t && $len_post < $nb_t } {
		puts "Warning: Unused transitions found."
	}
	for { set element 0 } { $element < $len_pre } { incr element } {
		set index_ligne [lindex [lindex $pre $element] 0]
		set index_colonne [lindex [lindex $pre $element] 1]
		set poids [lindex [lindex $pre $element] 2]
		vexpr {
			poids=poids*1.0
			PRE[index_ligne,index_colonne]=poids
		}
	}

	for { set element 0 } { $element < $len_post } { incr element } {
		set index_ligne [lindex [lindex $post $element] 0]
		set index_colonne [lindex [lindex $post $element] 1]
		set poids [lindex [lindex $post $element] 2]
		vexpr {
			poids=poids*1.0
			POST[index_ligne,index_colonne]=poids
		}
	}
	for { set element 0 } { $element < $len_mar } { incr element } {
		set index_place [lindex [lindex $mar $element] 0]
		set marquage [lindex [lindex $mar $element] 1]
		vexpr {
			marquage=marquage*1.0
			M[index_place,0]=marquage
		}
	}

	# writing to ouput structure matrix TCL file
	puts $fd_out_mat "############## Petri net structure description ###################################"
	puts $fd_out_mat "vectcl::vexpr { \n \t Post=create({$POST}); #def Post \n \t Pre=create({$PRE}); #def Pre \n}";
	puts $fd_out_mat "vectcl::vexpr { \n \t M=create({$M}) ; #Marquage_Initial \n \t nb_t=$nb_t; #nombre de transitions \n \t nb_p=$nb_p; #nombre de place \n}"
	#Report:
	puts "Petri net structure matrix successfully written to $pn_struct_matrix_tcl_file"
	puts "  Number of transitions: $nb_t / number of places: $nb_p"
	#Fermeture Buffers:
	close $fd_out_mat
	close $fd_in_ndr
}
