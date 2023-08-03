FROM ubuntu:22.04

# WebAoolication 配置用
ENV ENV_DIR_WEBAPP  /usr/src/app

USER root
RUN mkdir -p ${ENV_DIR_WEBAPP}
WORKDIR ${ENV_DIR_WEBAPP}

RUN apt-get update && apt-get install -y --no-install-recommends build-essential libreadline-dev \ 
libncursesw5-dev libssl-dev libsqlite3-dev libgdbm-dev libbz2-dev liblzma-dev zlib1g-dev uuid-dev libffi-dev libdb-dev python3-dev

# for OpenCV library
RUN apt-get install -y libgl1-mesa-dev libglib2.0-0

# install Python3 and etc
RUN apt-get install -y python3.9 python3-pip git wget vim

COPY requirements.txt  ${ENV_DIR_WEBAPP}
RUN pip3 install --upgrade pip
RUN pip3 install Cython==3.0.0b2
#RUN pip3 install setuptools wheel
RUN pip3 install numpy
#RUN pip3 install --user cython
RUN pip3 install -r ${ENV_DIR_WEBAPP}/requirements.txt
RUN echo 'alias ll="ls -al"' >> /root/.bashrc

COPY app  ${ENV_DIR_WEBAPP}
RUN ls -al ${ENV_DIR_WEBAPP}
RUN chmod 777 -R ${ENV_DIR_WEBAPP}

RUN apt-get update
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
RUN echo "Asia/Tokyo" > /etc/timezone

RUN git clone https://github.com/Kazuhito00/yolox-bytetrack-mcmot-sample && cd yolox-bytetrack-mcmot-sample
RUN wget https://github.com/Megvii-BaseDetection/YOLOX/releases/download/0.1.1rc0/yolox_s.onnx -P model

COPY app  ${ENV_DIR_WEBAPP}

