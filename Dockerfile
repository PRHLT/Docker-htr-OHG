FROM nvidia/cuda:10.0-base
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y vim build-essential devscripts \
gawk wget git automake autoconf sox gfortran libtool subversion python2.7 python3.7 \
libopencv-dev build-essential checkinstall cmake pkg-config yasm libtiff5-dev \
libjpeg-dev libavcodec-dev libavformat-dev libswscale-dev \
libdc1394-22-dev libxine2-dev software-properties-common \
libv4l-dev python-dev python-numpy python3-pip libtbb-dev libqt4-dev libgtk2.0-dev \
libfaac-dev libmp3lame-dev libopencore-amrnb-dev libopencore-amrwb-dev \
libtheora-dev libvorbis-dev libxvidcore-dev x264 v4l-utils ffmpeg \
libeigen3-dev liblog4cxx-dev libboost-all-dev imagemagick parallel xmlstarlet \
&& rm -rf /var/lib/apt/lists
RUN add-apt-repository ppa:ubuntu-toolchain-r/test && apt update && apt -y install gcc-9 g++-9 
RUN mkdir pidocs-soft
WORKDIR /pidocs-soft
###### KALDI
RUN git clone https://github.com/kaldi-asr/kaldi.git
WORKDIR /pidocs-soft/kaldi/tools
RUN ./extras/install_mkl.sh
RUN ./extras/check_dependencies.sh
RUN make -j 4
WORKDIR /pidocs-soft/kaldi/src
RUN ./configure --shared
RUN make depend -j 4
RUN make -j 4
###### CONVERT
WORKDIR /pidocs-soft/kaldi
RUN mkdir convert
RUN cp egs/wsj/s5/utils/convert_slf.pl convert/convert_slf.pl
###### ANACONDA 
COPY build-resource/.bashrc /root/
WORKDIR /pidocs-soft/
RUN wget --quiet https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh -O ./anaconda.sh
RUN bash anaconda.sh -b
COPY build-resource/pylaia.yml /pidocs-soft/
RUN ~/anaconda3/bin/conda init bash
RUN . ~/.bashrc
RUN ~/anaconda3/bin/conda env create -f pylaia.yml
###### PYLAIA
RUN git clone https://github.com/jpuigcerver/PyLaia
WORKDIR /pidocs-soft/PyLaia/
RUN git checkout "7ee6b8c"
###### LATTICE-CHAR-TO-WORD
WORKDIR /pidocs-soft/
RUN git clone https://github.com/jpuigcerver/lattice-char-to-word
ENV KALDI_ROOT=/pidocs-soft/kaldi/
WORKDIR /pidocs-soft/lattice-char-to-word/
RUN make
###### DOWNLOAD PAGE TOOLS
WORKDIR /pidocs-soft/page_tools/
RUN  wget --no-check-certificate https://www.prhlt.upv.es/~mavilrui/page_tools.zip
RUN unzip page_tools.zip
###### PAGE2TEI
WORKDIR /root/
RUN git clone --recursive https://github.com/skvark/opencv-python.git && cd opencv-python/opencv && git checkout 2.4 && mkdir -p build && cd build && cmake ../ && cmake --build . && make install
RUN echo "/usr/local/lib/" > /etc/ld.so.conf.d/opencv.conf
RUN apt-get -y --purge remove libboost-all-dev libboost-doc libboost-dev
RUN apt-get -y install build-essential g++ python-dev autotools-dev libicu-dev libbz2-dev
RUN wget http://downloads.sourceforge.net/project/boost/boost/1.58.0/boost_1_58_0.tar.gz && tar -zxvf boost_1_58_0.tar.gz && cd boost_1_58_0 && ./bootstrap.sh && ./b2 install
RUN echo "/usr/local/lib/" > /etc/ld.so.conf.d/libboost_system.so.1.58.0.conf
RUN ldconfig -v
WORKDIR /pidocs-soft/
RUN mkdir page2tei
WORKDIR /pidocs-soft/page2tei/
RUN cp /pidocs-soft/page_tools/page2tei .
##### CONTOUR GENERATOR AND LINE EXTRACTOR
WORKDIR /pidocs-soft/
RUN mkdir lineProcessing
RUN mkdir lineProcessing/pageContourGenerator_rot
RUN mkdir lineProcessing/pageLineExtractor_rot
WORKDIR /pidocs-soft/lineProcessing/pageContourGenerator_rot/
RUN cp /pidocs-soft/page_tools/page_format_generate_contour .
WORKDIR /pidocs-soft/lineProcessing/pageLineExtractor_rot/
RUN cp /pidocs-soft/page_tools/page_format_tool .
##### LAST ADDITIONS
RUN apt-get install -y rename
RUN apt-get install -y zip
##### RUN
WORKDIR /root
COPY build-resource/run.sh ./
COPY build-resource/xml_page_check.py ./
CMD . /root/.bashrc && conda init bash && conda activate pylaia && python3 /root/xml_page_check.py /data/page/ && [ ! -f xml_errors ] && bash /root/run.sh 
