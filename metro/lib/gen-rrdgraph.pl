#!/usr/bin/perl

# $Id: genere-rrdgraph,v 1.5 2009-08-24 08:02:58 boggia Exp $
# ###################################################################
# boggia : Creation : 21/05/08
#
# script permettant de g�n�rer un graphique rrdtools en fonction 
# du type de graphique pass� en param�tre ou que l'on trouve dans le 
# fichier index.graph ou metro.graph
# Le graphique est envoy� sur la sortie standard.
# 

# parametres : 
#   type_graph	    => (optionnel) 
#			Indique la nature du graphique � cr�er. (trafic, CPU ...)
#			S'il n'existe pas, le type de graphique est d�termin�
#			dans les fichiers *.graph
#   id		    =>	Liste des graphiques o� des points de metro.
#			Plusieurs cas possibles :   
#			    - un nom de graphique. Il s'agit d'un graphique
#			      les fichiers *.graph
#			    - une liste de points de metro a grapher, ex :
#			      Minsa-ap1.osiris+Minsa-ap2.osiris,Minsa-ap1.osiris-sec
#			      Les lignes de graphiques sont s�par�es par une ","
#			      Un ligne peut �tre cr��e � partir de plusieurs Points
#			      de METRO additionn�s gr�ce au symbol "+"
#   date_dep	    => d�but de l'intervalle de temps (time_t)
#   date_fin	    => fin de l'intervalle de temps (time_t)
#   taille	    => dimensions du graphique
#			    petit, moyen, grand ou <largeur>x<hauteur> (330x150)
#   commentaire	    => (optionnel) Commentaire qui s'affiche en titre (ex : interface ge-1/0/1)
#   legendes	    => (optionnel) L�gendes qui accompagne chaque ligne. A envoyer 
#		       sous forme de liste, ex: 
#		       "ssid osiris,ssid osiris-sec"

use strict;
use RRDTool::OO;

my $id = $ARGV[0];
my $type_graph = $ARGV[1];
my $date_dep = $ARGV[2];
my $date_fin = $ARGV[3];
my $taille = $ARGV[4];
my $commentaire = $ARGV[5];
my $legendes = $ARGV[6];

#system("echo $id >> /tmp/genere_graph.out");

require "%NMLIBDIR%/libmetro.pl";

# lecture du fichier de configuration general
our %global_conf = read_global_conf_file("%CONFFILE%");

# load graph library
require "%NMLIBDIR%/libgraph.pl";

# repertoire dans lequel sont stockees les definitions de graphs
our $dir_graph = $global_conf{metrodatadir} . "/graph" ;

# fichiers dans lesquels se trouvent la liste des graphiques existants avec le modele a utiliser
opendir(DIR, $dir_graph);
our @files_rrd_graph=grep(/\.graph$/, readdir DIR);
closedir(DIR);

if($id ne "-")
{
    #  on extrait la liste des sondes de l'argument $id
    my @l_bases = extract_list_bases($id);
   
    # on recupere les parametres du graphique dans les fichiers de conf
    @l_bases = get_graph(@l_bases);

    # on recupere les legendes
    my @legends = split(/,/,$legendes);

    # controle les type des bases, doit etre le meme pour toutes
    my $type = "";
    my $incoherence = 0;
    my $nb_rrd_bases = 0;
    my $l;
     
    for($l=0;$l<@l_bases;$l++)
    {
	my $tt_l_bases = @{$l_bases[$l]};
	for(my $j=0;$j<$tt_l_bases;$j++)
	{
	    # teste si les graphs ont tous le meme type
	    if($l_bases[$l][$j]{'type'} ne $type && $type ne "")
	    {	
		$incoherence = 1;
	    }
	    $type = $l_bases[$l][$j]{'type'};

	    # insertion de la legende
	    if($legends[$l])
	    {
		$l_bases[$l][$j]{'legend'} = $legends[$l];
	    }
 
	    $nb_rrd_bases ++;
	}
    }
    # s'il n'y a pas de coherence dans les graphiques	
    if($incoherence == 1)
    {
	print "erreur : il y a plusieurs type de graphiques diff�rents";
    }
    else
    # sinon, on continue
    {
	if($type_graph ne "-")
	{
	    $type = $type_graph;
	}

	my $l_ref = \@l_bases;

	genere_graph($type,$nb_rrd_bases,$l_ref,'-',$date_dep,$date_fin,$taille,$commentaire);
    } 
}
else
{
   print "erreur : aucun graphique ou point de m�trologie en parametre"; 
}


#######################################################################
#
#   FONCTIONS ASSOCIEES
#

########
# fonction qui recherche les parametres de cr�ation d'un graphique dans
# les fichiers de type metro.graph par rapport au nom du graphique
sub get_graph
{
    my (@l_bases) = @_;

    my $i;
    my $t = @files_rrd_graph;
 
    for($i=0;$i<$t;$i++)
    {
	# cherche le graph dans le fichier
 	open(INDEXGRAPH,"$dir_graph/$files_rrd_graph[$i]");

	my $line;
	while($line = <INDEXGRAPH>)
	{
	    chomp $line;
	    my ($nom) = (split(/;/,$line))[0];

	    my $t_l_bases = @l_bases;

	    my $termine = 1; 
	    for(my $j=0;$j<$t_l_bases;$j++)
	    {
		my $tt_l_bases = @{$l_bases[$j]};
    
		for(my $k=0;$k<$tt_l_bases;$k++)
		{   
		    if($l_bases[$j][$k]{'graph'} eq $nom)
		    {
			# nom trouv�
			my ($commande_modele,$nb_rrddata,$liste_rrddata,$legendes)=(split(/;/,$line))[1,2,3,4];
		
			# cas particulier de plusieurs bases dans la variable liste_rrddata
			if($liste_rrddata=~m/,/)
			{	
			    my @liste_rrd_data = split(/,/,$liste_rrddata);
			    my $t_liste_rrd_data = @liste_rrd_data;

			    # si le modele de commande est aggreg
			    # alors on trace une ligne par base
			    if($commande_modele =~m/aggreg/)
			    {
				for(my $l=0;$l<$t_liste_rrd_data;$l++)
				{   
				    $l_bases[$j+$l][$k]{'graph'} = $nom . $l;
				    $l_bases[$j+$l][$k]{'base'} = $liste_rrd_data[$l];
				    $l_bases[$j+$l][$k]{'type'} = $commande_modele;
				    if($legendes)
				    {
					$l_bases[$j+$l][$k]{'legend'} = get_legend($legendes,$l);
				    }
				}
				$j = $j + $t_liste_rrd_data -1;
				$t_l_bases = $t_l_bases + $t_liste_rrd_data -1;
			    }
			    # sinon on trace une ligne pour toutes les bases
			    else
			    {
				for(my $l=0;$l<$t_liste_rrd_data;$l++)
                                {
				    $l_bases[$j][$k+$l]{'graph'} = $nom . $l;
				    $l_bases[$j][$k+$l]{'base'} = $liste_rrd_data[$l];
				    $l_bases[$j][$k+$l]{'type'} = $commande_modele;
				    if($legendes)
                                    {
                                        $l_bases[$j][$k+$l]{'legend'} = get_legend($legendes,$l);
                                    }
				}
				$k = $k + $t_liste_rrd_data -1;
				$tt_l_bases = $tt_l_bases + $t_liste_rrd_data -1;
			    }
			}
			else
			{
			    # remplissage des param�tres avec le chemin des bases rrdtools
			    $l_bases[$j][$k]{'base'} = $liste_rrddata;
			    $l_bases[$j][$k]{'type'} = $commande_modele;
			}
		    }
		    # controle si toutes les bases ont ete trouvees
		    if(!exists $l_bases[$j][$k]{'base'})
		    {
			$termine = 0;
		    }
		}
	    }
	    if($termine == 1)
            {
		close(INDEXGRAPH);
                return @l_bases;
            }
	}
	close(INDEXGRAPH);
    }
    
    # on n'a rien trouv�
    return @l_bases;
}


########################################################################
#
#   fonction qui extrait la liste des sondes pass�es en param�tres
#
sub extract_list_bases
{
    ($id) = @_;
    
    my @l_bases;

    my @liste_metro = split(/,/,$id);
    my $t_liste = @liste_metro;

    my $i;
    for($i=0;$i<$t_liste;$i++)
    {
	
        if($liste_metro[$i]=~m/\+/)
        {
            my @l2 = split(/\+/,$liste_metro[$i]);
            my $t_l2 = @l2;
            my $j;
            for($j=0;$j<$t_l2;$j++)
            {
		$l_bases[$i][$j]{'graph'} = $l2[$j];
            }
        }
        else
        {
	    if($liste_metro[$i] eq "")
	    {
		$l_bases[$i][0]{'graph'} = "ERROR";
	    }
	    else
	    {
		$l_bases[$i][0]{'graph'} = $liste_metro[$i];
	    }
        }
    }
 
    return @l_bases;
}


########################################################################
#
#  Prend en param�tres une chaine de caract�res et un num�ro d'indice
#  puis parse la chaine de caract�res et renvoie les caract�res
#  positionn�s selon l'indice.
#  ex : chaine : legend:toto,titi,tata      indice : 1
#  renvoie : titi
#
sub get_legend
{
    my ($legendes,$l) = @_;

    chomp $legendes;
    ($legendes)=(split(/legend:/,$legendes))[1];
    
    my @leg = split(/,/,$legendes);

    return $leg[$l];
}
