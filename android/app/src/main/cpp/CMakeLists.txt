cmake_minimum_required(VERSION 3.22.1)
project(tannhauser_audio_engine C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Direktori include lokal dan library pihak ketiga (libusb & FFmpeg)
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/include/libusb
    ${CMAKE_CURRENT_SOURCE_DIR}/engine
    ${CMAKE_CURRENT_SOURCE_DIR}/jni
)

# Source files C++ Engine & JNI Bridge
set(SOURCE_FILES
    jni/jni_bridge.cpp
    engine/audio_engine.cpp
    engine/audio_decoder.cpp
    engine/usb_driver.cpp
    engine/peq_engine.cpp
)

# Target shared library
add_library(native-audio-engine SHARED ${SOURCE_FILES})

# Link library sistem Android
find_library(log-lib log)
target_link_libraries(native-audio-engine ${log-lib})

# Cek & Link library pihak ketiga (libusb & FFmpeg) jika file .so sudah tersedia
set(PREBUILT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libs/${ANDROID_ABI})

macro(link_prebuilt_if_exists LIB_NAME FILE_NAME)
    if(EXISTS ${PREBUILT_DIR}/${FILE_NAME})
        add_library(${LIB_NAME} SHARED IMPORTED)
        set_target_properties(${LIB_NAME} PROPERTIES
            IMPORTED_LOCATION ${PREBUILT_DIR}/${FILE_NAME}
        )
        target_link_libraries(native-audio-engine ${LIB_NAME})
        message(STATUS "Found prebuilt library: ${FILE_NAME}")
    else()
        message(WARNING "Prebuilt library not found yet: ${PREBUILT_DIR}/${FILE_NAME} (will need to be added for full functionality)")
    endif()
endmacro()

link_prebuilt_if_exists(usb1.0 libusb1.0.so)
link_prebuilt_if_exists(avcodec libavcodec.so)
link_prebuilt_if_exists(avformat libavformat.so)
link_prebuilt_if_exists(avutil libavutil.so)
link_prebuilt_if_exists(swresample libswresample.so)
