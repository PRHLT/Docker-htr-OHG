#! /bin/bash

work_dir=`pwd`
payload_dir=${work_dir}/payload
lm_dir=${payload_dir}/LM
res_dir=${payload_dir}/result

max_num_act_states=2007483647
beam_search=15
lattice_beam=12
asf=0.818485839158
wip=-0.465178062773
max_mem=1048576
blank_symb="<ctc>"                 
whitespace_symb="{space}"          
eol_char="{EOL}"                  
dummy_char="<dummy>"
hmm_log_prob=0.5                  
hmm_nac_prob=0.5                  
ngram_order=6                      
batch_size=28
gpu=0
htr_height=64
n_proc=$(grep -c ^processor /proc/cpuinfo)
max_time=3
word_sep=($whitespace_symb $dummy_char ',' '(' ')' ';' '[' ']' '"' "'")
delimiters="{space}";

echo 'will cite' | parallel --citation 1> /dev/null 2> /dev/null &

ln -s /data/page/*.xml /data/

#[ -d ${res_dir} ] && rm -Rf ${res_dir};
[ -d ${res_dir} ] || mkdir ${res_dir};
cd ${res_dir};

mkdir extracted_images

SECONDS=0;
echo "Extracting images from pages [INIT]"

if [ ! -f extracted_all_images ]; then

	mkdir contour/

	for f in /data/*.xml; do
		echo $f;
		h=`basename $f .xml`;
		/pidocs-soft/lineProcessing/pageContourGenerator_rot/page_format_generate_contour -a 75 -d 25 -p $f -o contour/$h.xml
	done

	for f in contour/*.xml; do
		h=`basename $f .xml`;
		if [ ! -f extracted_$h ]; then
			[ -f extraction_error_image_$h ] && rm extraction_error_image_$h_*;
			#/pidocs-soft/pageExtractLines/_release/bin/page_extract_lines -i $f -o extracted_images/ -f
			/pidocs-soft/lineProcessing/pageLineExtractor_rot/page_format_tool -i /data/$h.tif -l $f -m FILE 
			#mv /data/contour/*.png extracted_images/
			for x in contour/*.png; do y=`basename $x .png`; mv $x extracted_images/; rm contour/$y.txt; done

			counter=0

			for i in `ls extracted_images/$h*.png`; do
				((counter=$counter+1))
				j=`echo $i | cut -d '/' -f2`;
				identify extracted_images/$j | awk '{print $3}' > identified_$j; 
				width=`cat identified_$j | cut -d 'x' -f1`;
				height=`cat identified_$j | cut -d 'x' -f2`;
				#echo $j;
				#cat identified_$j;
				#echo $width $height;
				if [ $width -lt 20 ]; then echo "Image $j in page $h is not wide enough $width line $counter in xml [ERROR]" >> extraction_error_image_$h; fi
				if [ $width -gt 2500 ]; then echo "Image $j in page $h is too wide $width line $counter in xml [ERROR]" >> extraction_error_image_$h; fi
				if [ $height -lt 20 ]; then echo "Image $j in page $h is not tall enough $height line $counter in xml [ERROR]" >> extraction_error_image_$h; fi
				if [ $height -gt 550 ]; then echo "Image $j in page $h is too tall $height line $counter in xml [ERROR]" >> extraction_error_image_$h; fi
				rm identified_$j;
			done

			if [ -f extraction_error_image_$h ]; then 
				cat extraction_error_image_$h;
			else
				touch extracted_$h
			fi
		fi
	done

	if [ -f extraction_error_* ]; then
		cat extraction_error_*
		echo "There are unsolved extraction errors [ERROR]";
		exit 1;
	else
		touch extracted_all_images;
	fi

	cd extracted_images/
	for i in *; do mv $i `echo $i | cut -d_ -f1,4,5,6,7,8,9,10,11,12,13,14,15 | sed 's/_T/.T/g' | sed 's/_t/.t/g' | sed 's/_l/.l/g' | sed 's/_L/.L/g' | sed 's/_R/.r/g' | sed 's/_r/.r/g'`; done
	cd ..
fi
extraction_seconds=$SECONDS
echo "Extracting images from pages [DONE] $extraction_seconds"

list_seconds=$SECONDS
echo "Generating images list [INIT]"
if [ ! -f lines.lst ]; then
	ls extracted_images/ > kkk;
	cat kkk | cut -d '/' -f2 > lines.lst;
	sed -i 's/.png//g' lines.lst;
	rm kkk;
fi	
generation_seconds=$SECONDS
echo "Generating images list [DONE] $(($generation_seconds - $list_seconds))"

mkdir conf_matrix_results

list_seconds=$SECONDS
echo "Calculating confidence matrix [INIT]"
if [ ! -f calculated_conf_matrix ]; then

	[ -f conf_matrix_error ] && rm conf_matrix_error;

	if [ ! -f ConfMats.ark ]; then
		pylaia-htr-netout --gpu $gpu --train_path /optical/ --model_filename "model.pth" --checkpoint "experiment.ckpt.lowest-valid-cer-43" --batch_size $batch_size --output_transform "log_softmax" --output_matrix "conf_matrix_results/ConfMats.ark" /optical/symbs.txt extracted_images lines.lst
		#pylaia-htr-netout --trainer.gpus $gpu --common.train_path /optical/ --common.model_filename "model.pth" --common.checkpoint "/optical/experiment.ckpt.lowest-valid-cer-43" --logging.level INFO --logging.to_stderr INFO --logging.filepath conf_matrix_results/CMs-crnn.log --data.batch_size $batch_size --netout.output_transform "log_softmax" --netout.matrix "conf_matrix_results/ConfMats.ark" --trainer.progress_bar_refresh_rate 1 --img_dirs ["extracted_images"] lines.lst   

		#mv /optical/experiment/conf_matrix_results/CMs-crnn.log conf_matrix_results/CMs-crnn.log
		#mv /optical/experiment/conf_matrix_results/ConfMats.ark conf_matrix_results/ConfMats.ark

		rm -rf /optical/conf_matrix_results

	copy-matrix --verbose=0 "ark:conf_matrix_results/ConfMats.ark" "ark,scp:conf_matrix_results/prod_mat.ark,conf_matrix_results/prod_mat.scp"

	fi

	featdim=$(feat-to-dim scp:conf_matrix_results/prod_mat.scp - 2>/dev/null)

	num_lst=`cat lines.lst | wc -l`;
	num_conf=`cat conf_matrix_results/prod_mat.scp | wc -l`;
	if [ $num_lst -ne $num_conf ]; then
		echo "Stopped processing due to lst($num_lst) conf_mat($num_conf) mismatch [ERROR]" > conf_matrix_error;
		cat conf_matrix_error;
		exit 1;
	else
		touch calculated_conf_matrix;
	fi

fi
conf_matrix_seconds=$SECONDS
echo "Calculating confidence matrix [DONE] $(($conf_matrix_seconds - $list_seconds))"

mkdir lattice_results

list_seconds=$SECONDS
echo "Calculating lattices [INIT]"
if [ ! -f calculated_lattices ]; then

	[ -f lattices_error ] && rm lattices_error;

	ln -s conf_matrix_results/prod_mat.ark .
	ln -s conf_matrix_results/prod_mat.scp .

	latgen-faster-mapped-parallel --verbose=0 --num-threads=$(nproc) --allow-partial=true --acoustic-scale=${asf} --max-active=${max_num_act_states} --beam=${beam_search} --lattice-beam=${lattice_beam} --max-mem=${max_mem} /language_model/new.mdl /language_model/HCLG.fst scp:prod_mat.scp "ark:|gzip -c > lattice_results/lat.gz" ark,t:lattice_results/RES 2>lattice_results/LOG-Lats

	latt_num=`cat lattice_results/RES | wc -l`;
        conf_num=`cat conf_matrix_results/prod_mat.scp | wc -l`;
	if [ ${latt_num} -ne ${conf_num} ]; then
		echo "Stopped processing ${d} due to latt(${latt_num}) conf_mat(${conf_num}) mismatch [ERROR]" > lattices_error;
		cat lattices_error;
		exit 1;
	else
		touch calculated_lattices;
	fi

fi
lattices_seconds=$SECONDS
echo "Calculating lattices [DONE] $(($lattices_seconds - $list_seconds))"

mkdir transcriptions

list_seconds=$SECONDS
echo "Generating transcriptions [INIT]"
if [ ! -f transcriptions_generated ]; then

	[ -f transcriptions_error ] && rm transcriptions_error;

	if [ ! -f lattices_scaled ]; then

		lattice-scale --acoustic-scale=${asf} "ark:gunzip -c lattice_results/lat.gz|" ark:- | \
		lattice-add-penalty --word-ins-penalty=${wip} ark:- ark:- | \
		lattice-best-path ark:- "ark,t:| /pidocs-soft/kaldi/egs/wsj/s5/utils/int2sym.pl -f 2- /language_model/words.txt > hyp.txt"

		touch lattices_scaled;

	fi

	if [ ! -f hypothesis_processed ]; then
		
		cat hyp.txt | awk -v odir=transcriptions/ \
		'{fh=$1;gsub($1,"",$0);gsub(" ","",$0);gsub("{space}"," ",$0);
		print $0 > odir"/"fh".txt"}'

		touch hypothesis_processed;

	fi

	hyp_num=`cat hyp.txt | wc -l`;
	trans_num=`ls transcriptions | wc -l`;
	if [ $trans_num -ne $hyp_num ]; then
		echo "Stopped processing due to hypothesis(${hyp_num}) transcriptions(${trans_num}) mismatch [ERROR]" > transcriptions_error;
                cat transcriptions_error;
                exit 1;
	else
		touch transcriptions_generated;
	fi

fi
transcriptions_seconds=$SECONDS
echo "Generating transcritions [DONE] $(($transcriptions_seconds - $list_seconds))"

mkdir page

f_list=tif_list.lst
ls /data/*.tif > tif_list.lst

list_seconds=$SECONDS
echo "Generating page files [INIT]"
if [ ! -f page_files_generated ]; then

	for f in $(<$f_list); do
		n=$(basename $f .tif);
		d=$(dirname $f);
		awk '{if(($0!~"TextEquiv>")&&($0!~"Unicode>")) print $0}' /data/${n}.xml > page/${n}.xml
		for l in transcriptions/*${n}*.txt; do
			l_id=`echo $l | grep -Po  '[a-zA-Z]+ine_[0-9]+_[0-9]+'`;
			if [ -z "$l_id" ]; then l_id=`echo $l | grep -Po  '[a-zA-Z]+ine_[0-9]+'`; fi 
				xmlstarlet ed --inplace -N x="http://schema.primaresearch.org/PAGE/gts/pagecontent/2013-07-15" -d "///*[@id=\"${l_id}\"]/x:TextEquiv" -s "///*[@id=\"${l_id}\"]" -t elem -n TMPNODE -v "" -s //TMPNODE -t elem -n Unicode -v "$(<$l)" -r //TMPNODE -v TextEquiv page/${n}.xml
		done
	done

	touch page_files_generated

fi
page_files_seconds=$SECONDS
echo "Generating page files [DONE] $(($page_files_seconds - $list_seconds))"

mkdir sampling
mkdir PRHLT_DATA

t_list=t_list.lst
ls extracted_images/ | cut -d_ -f1 | uniq > k
while read i; do echo "extracted_images/$i.tif" >> t_list.lst; done < k

list_seconds=$SECONDS
echo "Generating sampling [INIT]"
if [ ! -f sampling_generated ]; then

	SDIR=sampling
	mkdir -p $SDIR/word
	cat $t_list | sort -R | head -n 25 | xargs -n1 -I {} basename {} | cut -d. -f1 > $SDIR/random_sampling.lst	
	tmp_dir=$SDIR/tmp_$(((RANDOM%99999) +1 )) 
	mkdir -p $tmp_dir/word
	lattice-copy "ark:gunzip -c lattice_results/lat.gz |" ark,t:- | awk -v out=$tmp_dir -v RS= '{print > (out"/tmp-" NR ".lat")}'
	grep -r -m1 -f $SDIR/random_sampling.lst $tmp_dir/ > $SDIR/to_word_lat.lst

	int_word_sep=`awk -v WS="${word_sep[*]}" 'BEGIN {
                                                  split(WS, A, / /);
                                                  for (i in A) B[A[i]] = ""
                                                  }
                                                  $1 in B{
                                                  printf "%d ",$2
                                                  }' /language_model/words.txt | sed 's:\s\+$::g'`
	
	for l in $(cut -d ":" -f1 $SDIR/to_word_lat.lst); do
		lat_name=`basename $l`;
		timeout -s 9 $max_time /pidocs-soft/lattice-char-to-word/lattice-char-to-word --beam=10.0 \
		--save-symbols=${tmp_dir}/${lat_name}_symbs.lst \
		"$int_word_sep" \
		"ark:$l" "ark,t:${tmp_dir}/${lat_name}_tmp.lat" || \
		/pidocs-soft/lattice-char-to-word/lattice-char-to-word --beam=5.0 --save-symbols=${tmp_dir}/${lat_name}_symbs.lst \
		"$int_word_sep" \
		"ark:$l" "ark,t:${tmp_dir}/${lat_name}_tmp.lat";
		awk '{print $2" "$1}' ${tmp_dir}/${lat_name}_symbs.lst |
		sed 's/_/ /g' | /pidocs-soft/kaldi/egs/wsj/s5/utils/int2sym.pl -f 2- /language_model/words.txt |
		awk '{for(i=2;i<=NF;i++) printf("%s", $i); print " "$1}' > ${tmp_dir}/${lat_name}_symbs.dic
		lattice-copy "ark:${tmp_dir}/${lat_name}_tmp.lat"  ark,t:- |
		/pidocs-soft/kaldi/egs/wsj/s5/utils/int2sym.pl -f 3 ${tmp_dir}/${lat_name}_symbs.dic > ${tmp_dir}/${lat_name}_w.lat
		/pidocs-soft/kaldi/convert/convert_slf.pl  ${tmp_dir}/${lat_name}_w.lat $tmp_dir/word/
	done
	wait;

	for l in $tmp_dir/word/*.lat.gz; do
	name=`basename $l .gz`
        zcat $l | sed 's/{space}/!NULL/g' | \
            awk 'BEGIN{
                    FS = "[ =\t]";
                    prev=0;
                    v=0;
                    t=0;
                }
                NR <= 2{
                    print $0;
                }
                $1=="N"{
                    print"N="$2+1 "\tL="$4+1
                }
                $1=="I"{
                    print $0;
                    prev=$1;
                    v=$2;
                    t=$4 
                }
                prev=="I" && $1=="J"{ 
                    print "I="v+1"\tt="t+0.03;
                    prev=$1;
                }
                $1=="J"{ 
                    v=$2;
                    S[$4]=1;
                    E[$6]=1;
                    M=$6;
                    W[$2]=$8;
                    print $0;
                }
                END{
                    for (e in E){
                        if (e in S == 0) {
                            print "J="v+1 "\tS="e "\tE="M+1 "\tW=</s>\tv=1.0\ta=250.0\tl=-10";
                            v++;
                        }
                    }
                }' > $SDIR/word/$name
	done

	mv $SDIR/word/* PRHLT_DATA/ 
	mkdir PRHLT_DATA/images
	mkdir PRHLT_DATA/page
	while read i; do
		cp /data/$i.tif PRHLT_DATA/images/$i.tif;
		cp /data/page/$i.xml PRHLT_DATA/page/$i.xml;
	done < $SDIR/random_sampling.lst;
	cd PRHLT_DATA/images;
	for i in *.tif; do convert $i ${i/tif/jpg}; rm $i; done;
	for i in *.jpg; do j=$(basename $i .jpg)_thumb.jpg; convert $i -resize x100 -quality 90% $j; done; 
	cd ../..;
	zip -r PRHLT_DATA.zip PRHLT_DATA/;

	touch sampling_generated;

fi
sampling_seconds=$SECONDS
echo "Generating sampling [DONE] $(($sampling_seconds - $list_seconds))"

mkdir tei

list_seconds=$SECONDS
echo "Generating TEI files [INIT]"
if [ ! -f tei_generated ]; then

	cd page;
	sed -i '/TextLine/ s@}">@} catti {revised:False;}">@g' *.xml;
	cd ../..;
	ln -s /data/*.tif .
	for f in `ls result/page/*.xml`; do 
		/pidocs-soft/page2tei/page2tei -l $f -o result/tei/ -m FILE; 
	done;
	for l in *.tif; do unlink $l; done;
	cd result/tei;
	rename 's:tei:xml:g' *.tei;
	cd ..;

	touch tei_generated;

fi
tei_generation_seconds=$SECONDS
echo "Generating TEI files [DONE] $(($tei_generation_seconds - $list_seconds))"

list_seconds=$SECONDS
echo "Removing intermediate files [INIT]"

cd ..
cp -r result/page/ .
cp -r result/tei/ .
cp result/PRHLT_DATA.zip .
rm -rf result/

removing_files_seconds=$SECONDS
echo "Removing intermediate files [DONE] $(($removing_files_seconds - $list_seconds))"

echo "Process completed [END] $SECONDS"
