# LeGO-LOAM (this fork) on ROS Melodic: Ubuntu 18.04, PCL 1.8, OpenCV 3 (opencv/cv.h), C++11 -- builds as is.
#   podman build -t memo/lego-loam:melodic external/LeGO-LOAM      # or docker build, with daemon access
#   (robolang: add --dns 128.83.120.30 -- the host's resolv.conf is systemd-resolved's 127.0.0.53 stub)
# memo runs it headless over bags with scripts/data/run_legoloam.py (scripts/data/legoloam/run_bag.sh).
FROM docker.io/library/ros:melodic-perception

ARG GTSAM_VERSION=4.0.0-alpha2
ENV DEBIAN_FRONTEND=noninteractive

# Rootless podman: apt's unprivileged _apt sandbox user cannot resolve hosts there; and IPv4 only
RUN printf 'APT::Sandbox::User "root";\nAcquire::ForceIPv4 "true";\n' > /etc/apt/apt.conf.d/99-container

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake wget unzip libboost-all-dev libtbb-dev \
        ros-melodic-pcl-ros ros-melodic-pcl-conversions ros-melodic-cv-bridge ros-melodic-tf \
        ros-melodic-image-transport ros-melodic-rosbag \
    && rm -rf /var/lib/apt/lists/*

# GTSAM as the fork's README asks: no -march=native (the image runs on other CPUs), the system Eigen
RUN wget -q -O /tmp/gtsam.zip https://github.com/borglab/gtsam/archive/${GTSAM_VERSION}.zip \
    && unzip -q /tmp/gtsam.zip -d /tmp && mkdir /tmp/gtsam-${GTSAM_VERSION}/build && cd /tmp/gtsam-${GTSAM_VERSION}/build \
    && cmake -DCMAKE_BUILD_TYPE=Release -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF -DGTSAM_USE_SYSTEM_EIGEN=ON \
             -DGTSAM_BUILD_TESTS=OFF -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF .. \
    && make -j"$(nproc)" install && ldconfig && rm -rf /tmp/gtsam*

WORKDIR /catkin_ws
COPY cloud_msgs src/cloud_msgs
COPY LeGO-LOAM src/LeGO-LOAM
# -j1 first: cloud_msgs' generated headers must exist before lego_loam compiles
RUN /bin/bash -c "source /opt/ros/melodic/setup.bash && catkin_make -j1 -DCMAKE_BUILD_TYPE=Release"

RUN sed -i 's|exec "\$@"|source /catkin_ws/devel/setup.bash\nexec "$@"|' /ros_entrypoint.sh
CMD ["bash"]
