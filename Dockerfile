# Copyright 2019 The MediaPipe Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM ubuntu:18.04

MAINTAINER <mediapipe@google.com>

WORKDIR /io
WORKDIR /mediapipe

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gcc-8 g++-8 \
        ca-certificates \
        curl \
        ffmpeg \
        git \
        wget \
        unzip \
        python3-dev \
        python3-opencv \
        python3-pip \
        libopencv-core-dev \
        libopencv-highgui-dev \
        libopencv-imgproc-dev \
        libopencv-video-dev \
        libopencv-calib3d-dev \
        libopencv-features2d-dev \
        software-properties-common && \
    add-apt-repository -y ppa:openjdk-r/ppa && \
    apt-get update && apt-get install -y openjdk-8-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 100 --slave /usr/bin/g++ g++ /usr/bin/g++-8
RUN pip3 install --upgrade setuptools
RUN pip3 install wheel
RUN pip3 install future
RUN pip3 install six==1.14.0
RUN pip3 install tensorflow==1.14.0
RUN pip3 install tf_slim

RUN ln -s /usr/bin/python3 /usr/bin/python

# Install bazel
ARG BAZEL_VERSION=3.7.2
RUN mkdir /bazel && \
    wget --no-check-certificate -O /bazel/installer.sh "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/b\
azel-${BAZEL_VERSION}-installer-linux-x86_64.sh" && \
    wget --no-check-certificate -O  /bazel/LICENSE.txt "https://raw.githubusercontent.com/bazelbuild/bazel/master/LICENSE" && \
    chmod +x /bazel/installer.sh && \
    /bazel/installer.sh  && \
    rm -f /bazel/installer.sh

# Download and generate the MediaPipe VGGish feature extraction graph
COPY . /mediapipe/
RUN mkdir /tmp/mediapipe
RUN cd /tmp/mediapipe && \
curl -O http://data.yt8m.org/pca_matrix_data/inception3_mean_matrix_data.pb && \
curl -O http://data.yt8m.org/pca_matrix_data/inception3_projection_matrix_data.pb && \
curl -O http://data.yt8m.org/pca_matrix_data/vggish_mean_matrix_data.pb && \
curl -O http://data.yt8m.org/pca_matrix_data/vggish_projection_matrix_data.pb && \
curl -O http://download.tensorflow.org/models/image/imagenet/inception-2015-12-05.tgz && \
tar -xvf /tmp/mediapipe/inception-2015-12-05.tgz
RUN python -m mediapipe.examples.desktop.youtube8m.generate_vggish_frozen_graph

# Build the youtube8m feature extraction example binary
RUN bazel build -c opt --linkopt=-s --define MEDIAPIPE_DISABLE_GPU=1 --define no_aws_support=true mediapipe/examples/desktop/youtube8m:extract_yt8m_features

# Install Flask
RUN pip3 install -U Flask

# Start the server
RUN export FLASK_APP=feature_extraction_server
RUN export FLASK_ENV=development
CMD ["flask", "run", "--host=0.0.0.0"]

# Use the stuff below instead for production
# RUN export FLASK_ENV=production
# CMD ["flask", "run", "--host=0.0.0.0"]


# ENTRYPOINT ["python"]
# CMD -m mediapipe.examples.desktop.youtube8m.generate_input_sequence_example --path_to_input_video=/shared/00_input_tmp/0002bz1GNsUP.mp4 --clip_end_time_sec=120 && GLOG_logtostderr=1 bazel-bin/mediapipe/examples/desktop/youtube8m/extract_yt8m_features --calculator_graph_config_file=mediapipe/graphs/youtube8m/feature_extraction.pbtxt --input_side_packets=input_sequence_example=/tmp/mediapipe/metadata.pb --output_side_packets=output_sequence_example=/shared/01_feature_pb_tmp/0002bz1GNsUP.pb

# If we want the docker image to contain the pre-built object_detection_offline_demo binary, do the following
# RUN bazel build -c opt --define MEDIAPIPE_DISABLE_GPU=1 mediapipe/examples/desktop/demo:object_detection_tensorflow_demo
