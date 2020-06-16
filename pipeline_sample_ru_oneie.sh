#!/usr/bin/env bash

######################################################
# Arguments
######################################################
data_root=$1
lang=$2
source=$3
use_nominal_corefer=1

# ltf source folder path
ltf_source=${data_root}/ltf
# rsd source folder path
rsd_source=${data_root}/rsd
# file list of ltf files (only file names)
ltf_file_list=${data_root}/ltf_lst
#ls ${ltf_source} > ${ltf_file_list}
# file list of rsd files (absolute paths, this is a temporary file)
rsd_file_list=${data_root}/rsd_lst
#readlink -f ${rsd_source}/* > ${rsd_file_list}

# edl output
edl_output_dir=${data_root}/edl
edl_bio=${edl_output_dir}/${lang}.bio
edl_tab_nam_filename=${lang}.nam.tagged.tab
edl_tab_nom_filename=${lang}.nom.tagged.tab
edl_tab_pro_filename=${lang}.pro.tagged.tab
edl_tab_nam=${edl_output_dir}/${edl_tab_nam_filename}
edl_tab_nom=${edl_output_dir}/${edl_tab_nom_filename}
edl_tab_pro=${edl_output_dir}/${edl_tab_pro_filename}
edl_tab_link=${edl_output_dir}/${lang}.linking.tab
edl_tab_link_fb=${edl_output_dir}/${lang}.linking.freebase.tab
edl_tab_coref_ru=${edl_output_dir}/${lang}.coreference.tab
geonames_features=${edl_output_dir}/${lang}.linking.geo.json
edl_tab_final=${edl_output_dir}/merged_final.tab
edl_cs_coarse=${edl_output_dir}/merged.cs
entity_fine_model=${edl_output_dir}/merged_fine.tsv
edl_cs_fine=${edl_output_dir}/merged_fine.cs
edl_json_fine=${edl_output_dir}/${lang}.linking.freebase.fine.json
edl_tab_freebase=${edl_output_dir}/${lang}.linking.freebase.tab
freebase_private_data=${edl_output_dir}/freebase_private_data.json
lorelei_link_private_data=${edl_output_dir}/lorelei_private_data.json
entity_lorelei_multiple=${edl_output_dir}/${lang}.linking.tab.candidates.json
edl_cs_fine_all=${edl_output_dir}/merged_all_fine.cs
edl_cs_info=${edl_output_dir}/merged_all_fine_info.cs
edl_cs_info_conf=${edl_output_dir}/merged_all_fine_info_conf.cs
edl_cs_color=${edl_output_dir}/${lang}.linking.col.tab
conf_all=${edl_output_dir}/all_conf.txt

# filler output
core_nlp_output_path=${data_root}/corenlp
filler_coarse=${edl_output_dir}/filler_${lang}.cs
filler_fine=${edl_output_dir}/filler_fine.cs
udp_dir=${data_root}/udp
chunk_file=${edl_output_dir}/chunk.txt

# relation output
relation_result_dir=${data_root}/relation   # final cs output file path
relation_cs_coarse=${relation_result_dir}/${lang}.rel.cs # final cs output for relation
relation_cs_fine=${relation_result_dir}/${lang}.rel.cs # final cs output for relation
new_relation_coarse=${relation_result_dir}/new_relation_${lang}.cs

# event output
event_result_dir=${data_root}/event
event_coarse_without_time=${event_result_dir}/events.cs
event_coarse_with_time=${event_result_dir}/events_tme.cs
event_fine=${event_result_dir}/events_fine.cs
event_frame=${event_result_dir}/events_fine_framenet.cs
event_depen=${event_result_dir}/events_fine_depen.cs
event_fine_all=${event_result_dir}/events_fine_all.cs
event_corefer=${event_result_dir}/events_corefer.cs
event_final=${event_result_dir}/events_info.cs
ltf_txt_path=${event_result_dir}/'ltf_txt'
framenet_path=${event_result_dir}/'framenet_res'

# final output
merged_cs=${data_root}/${lang}${source}_full.cs
merged_cs_link=${data_root}/${lang}${source}_full_link.cs


######################################################
# Running scripts
######################################################

# EDL
## entity extraction
echo "** Extracting entities **"
docker run --rm -v `pwd`:`pwd` -w `pwd` -i --network="host" limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_edl/edl.py \
    ${ltf_source} ${rsd_source} ${lang} ${edl_output_dir} \
    ${edl_bio} ${edl_tab_nam} ${edl_tab_nom} ${edl_tab_pro} \
    ${entity_fine_model}
## linking
echo "** Linking entities to KB **"
link_dir=system/aida_edl/edl_data/test
docker run -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    mkdir -p ${link_dir}/input
docker run -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    cp -r ${edl_output_dir}/* ${link_dir}/input/
docker run -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    ls ${link_dir}/input
docker run -v ${PWD}/system/aida_edl/edl_data:/data --link db:mongo panx27/edl \
    python ./projs/docker_aida19/aida19.py \
    ${lang} /data/test/input/ /data/test/output
docker run -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    cp ${link_dir}/output/* ${edl_output_dir}/
docker run -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    rm -rf ${link_dir}
## nominal coreference for ru and uk
docker run --rm -v `pwd`/data:/scr/data -w /scr -i dylandilu/chuck_coreference \
    python appos_extract.py \
    --udp_dir ${udp_dir} \
    --edl_tab_path ${edl_tab_link} \
    --path_out_coref ${edl_tab_final}
## tab2cs
docker run --rm -v `pwd`:`pwd` -w `pwd`  -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_edl/tab2cs.py \
    ${edl_tab_final} ${edl_cs_coarse} 'EDL'

 Relation Extraction (coarse-grained)
echo "** Extraction relations **"
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/aida_relation_coarse/bin/python \
    -u /relation/CoarseRelationExtraction/exec_relation_extraction.py \
    -i ${lang} \
    -l ${ltf_file_list} \
    -f ${ltf_source} \
    -e ${edl_cs_coarse} \
    -t ${edl_tab_final} \
    -o ${relation_cs_coarse}
## Filler Extraction & new relation
docker run --rm -v `pwd`/data:/scr/data -w /scr -i dylandilu/filler \
    python extract_filler_relation.py \
    --corenlp_dir ${core_nlp_output_path} \
    --ltf_dir ${ltf_source} \
    --edl_path ${edl_cs_coarse} \
    --text_dir ${rsd_source} \
    --path_relation ${new_relation_coarse} \
    --path_filler ${filler_coarse} \
    --lang ${lang}

## Fine-grained Entity
echo "** Fine-grained entity typing **"
docker run --rm -v `pwd`:`pwd` -w `pwd` -i --network="host" limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_edl/fine_grained_entity.py \
    ${lang} ${edl_json_fine} ${edl_tab_freebase} ${entity_fine_model} \
    ${geonames_features} ${edl_cs_coarse} ${edl_cs_fine} ${filler_fine} \
    --filler_coarse ${filler_coarse}
## Postprocessing, adding informative justification
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_utilities/pipeline_merge_m18.py \
    --cs_fnames ${edl_cs_fine} ${filler_fine} \
    --output_file ${edl_cs_fine_all}
echo "** Informative Justification **"
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_edl/entity_informative.py ${chunk_file} ${edl_cs_fine_all} ${edl_cs_info}
## update mention confidence
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_utilities/rewrite_mention_confidence.py \
    ${lang}${source} ${edl_tab_nam} ${edl_tab_nom} ${edl_tab_pro} \
    ${edl_tab_link} ${entity_lorelei_multiple} ${ltf_source} \
    ${edl_cs_info} ${edl_cs_info_conf} ${conf_all}

# Event (Coarse)
echo "** Extracting events for Ru **"
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
   /opt/conda/envs/ru_event/bin/python \
   ./ru_event/ru_event_backend.py \
   --ltf_folder_path ${ltf_source} \
   --input_edl_bio_file_path ${edl_bio} \
   --input_rsd_folder_path ${rsd_source} \
   --entity_cs_file_path ${edl_cs_coarse}
## Add time expression
docker run -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_event/postprocessing_add_time_expression.py \
    ${ltf_source} ${filler_coarse} ${event_coarse_without_time} ${event_coarse_with_time}

# Relation Extraction (fine)
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    -u /relation/FineRelationExtraction/EVALfine_grained_relations.py \
    --lang_id ${lang} \
    --ltf_dir ${ltf_source} \
    --rsd_dir ${rsd_source} \
    --cs_fnames ${edl_cs_coarse} ${filler_coarse} ${relation_cs_coarse} ${new_relation_coarse} \
    --fine_ent_type_tab ${edl_tab_freebase} \
    --fine_ent_type_json ${edl_json_fine} \
    --outdir ${relation_result_dir} \
    --fine_grained
##   --reuse_cache \
##   --use_gpu \


## Event (Fine-grained)
echo "** Event fine-grained typing **"
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_event/fine_grained/fine_grained_events.py \
    ${lang} ${ltf_source} ${edl_json_fine} ${edl_tab_freebase} \
    ${edl_cs_coarse} ${event_coarse_with_time} ${event_fine} \
    --filler_coarse ${filler_coarse} \
    --entity_finegrain_aida ${edl_cs_fine_all}
### Event Rule-based
#echo "** Event rule-based **"
#docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
#    /opt/conda/envs/py36/bin/python \
#    ./system/aida_event/framenet/new_event_dependency.py \
#    ${rsd_source} ${core_nlp_output_path} \
#    ${edl_cs_coarse} ${filler_coarse} ${event_fine} ${event_frame} ${event_depen}
### Combine fine-grained typing and rule-based
#docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
#    /opt/conda/envs/py36/bin/python \
#    ./system/aida_utilities/pipeline_merge_m18.py \
#    --cs_fnames ${event_fine} ${event_frame} ${event_depen} \
#    --output_file ${event_fine_all}
## Event coreference
echo "** Event coreference **"
docker run --rm -v `pwd`:`pwd` -w `pwd` -i --network="host" limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_event_coreference/gail_event_coreference_test_${lang}.py \
    -i ${event_fine} -o ${event_corefer} -r ${rsd_source}
### updating informative mention
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_event/postprocessing_event_informative_mentions.py \
    ${ltf_source} ${event_corefer} ${event_final}
echo "Update event informative mention"

# Final Merge
echo "** Merging all items **"
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_utilities/pipeline_merge_m18.py \
    --cs_fnames ${edl_cs_info_conf} ${edl_cs_color} ${relation_cs_fine} ${event_final} \
    --output_file ${merged_cs}
# multiple freebase links
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_utilities/postprocessing_link_freebase.py \
    ${edl_tab_freebase} ${merged_cs} ${freebase_private_data}
# multiple lorelei links
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    ./system/aida_utilities/postprocessing_link_confidence.py \
    ${entity_lorelei_multiple} ${merged_cs} ${merged_cs_link} ${lorelei_link_private_data}


echo "Final result in Cold Start Format is in "${merged_cs_link}
