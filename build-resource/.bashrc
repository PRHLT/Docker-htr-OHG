if [ -d "/pidocs-soft/kaldi" ] ; then
	export KALDI_ROOT="/pidocs-soft/kaldi"
	PATH="${KALDI_ROOT}/src/bin:${KALDI_ROOT}/src/chainbin:${KALDI_ROOT}/src/featbin:${KALDI_ROOT}/src/fgmmbin:${KALDI_ROOT}/src/fstbin:${KALDI_ROOT}/src/gmmbin:${KALDI_ROOT}/src/ivectorbin:${KALDI_ROOT}/src/kwsbin:${KALDI_ROOT}/src/latbin:${KALDI_ROOT}/src/lmbin:${KALDI_ROOT}/src/nnet2bin:${KALDI_ROOT}/src/nnet3bin:${KALDI_ROOT}/src/nnetbin:${KALDI_ROOT}/src/online2bin:${KALDI_ROOT}/src/onlinebin:${KALDI_ROOT}/src/rnnlmbin:${KALDI_ROOT}/src/sgmm2bin:${KALDI_ROOT}/src/sgmmbin:${KALDI_ROOT}/src/tfrnnlmbin:${KALDI_ROOT}/src/cudadecoderbin:$KALDI_ROOT/tools/openfst/bin:$KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe:/root/anaconda3/bin:/pidocs-soft/pageLineExtractor:/pidocs-soft/PyLaia:$PATH"
fi

echo "Logged in" 
