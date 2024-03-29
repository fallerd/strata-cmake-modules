##
## Copyright (c) 2018-2021 onsemi.
##
## All rights reserved. This software and/or documentation is licensed by onsemi under
## limited terms and conditions. The terms and conditions pertaining to the software and/or
## documentation are available at http://www.onsemi.com/site/pdf/ONSEMI_T&C.pdf (“onsemi Standard
## Terms and Conditions of Sale, Section 8 Software”).
##
execute_process(
    COMMAND ${GIT_EXECUTABLE} rev-parse 
    WORKING_DIRECTORY ${GIT_ROOT_DIR}
    RESULT_VARIABLE res_git_repo
)

if(NOT ${res_git_repo} EQUAL 0)
    message(FATAL_ERROR "${GIT_ROOT_DIR}\nis Not a git cloned project. Can't create version string from git tag!!")
endif()

if (USE_GITTAG_VERSION)
    message(STATUS "Searching for tag: '${GITTAG_PREFIX}v...'")
    execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --tags --dirty --match "${GITTAG_PREFIX}v*"
        WORKING_DIRECTORY ${GIT_ROOT_DIR}
        RESULT_VARIABLE res_var
        OUTPUT_VARIABLE GIT_COMMIT_ID
        ERROR_VARIABLE GIT_SKIP_ERROR_OUTPUT
    )
    message(STATUS "Searching for Git hash...'")
    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
        WORKING_DIRECTORY ${GIT_ROOT_DIR}
        RESULT_VARIABLE res_var3
        OUTPUT_VARIABLE GIT_REVISION
    )
    string(REGEX REPLACE "\n$" "" GIT_REVISION ${GIT_REVISION})
else()
    message(STATUS "Reading version strings from Git tags disabled. Defaulting to 'v0.0.0'...")
    set(GIT_COMMIT_ID "0.0.0\n")
endif()

if(NOT ${res_var} EQUAL 0)
    message(STATUS "SKIP, can't receive Git version (not a repo, or no project tags; code: ${res_var}). Defaulting to 'v0.0.1'...")
    set(GIT_COMMIT_ID "0.0.1\n")
endif()
string(REGEX REPLACE "\n$" "" GIT_COMMIT_ID ${GIT_COMMIT_ID})
string(REGEX REPLACE "^${GITTAG_PREFIX}v" "" GIT_COMMIT_ID ${GIT_COMMIT_ID})

# check number of digits in version string
string(REPLACE "." ";" GIT_COMMIT_ID_VLIST ${GIT_COMMIT_ID})
list(LENGTH GIT_COMMIT_ID_VLIST GIT_COMMIT_ID_VLIST_COUNT)

# no.: major
string(REGEX REPLACE "^([0-9]+)\\..*" "\\1" VERSION_MAJOR "${GIT_COMMIT_ID}")
# no.: minor
string(REGEX REPLACE "^[0-9]+\\.([0-9]+).*" "\\1" VERSION_MINOR "${GIT_COMMIT_ID}")

set(PROJECT_VERSION "v${VERSION_MAJOR}.${VERSION_MINOR}")
set(BUILD_ID ${PROJECT_VERSION_TWEAK})

if("${GIT_COMMIT_ID_VLIST_COUNT}" STREQUAL "2")
    # no.: patch
    set(VERSION_PATCH "0")
    # no.: optional, used for external components which require 4th version digit (for example openssl)
    set(VERSION_OPTIONAL "0")
    string(APPEND PROJECT_VERSION ".0")
    string(APPEND PROJECT_VERSION ".${BUILD_ID}")
    # SHA1 string + git 'dirty' flag
    string(REGEX REPLACE "^[0-9]+\\.[0-9]+(.*)" "\\1" VERSION_GIT_STATE "${GIT_COMMIT_ID}")
else()
    # no.: patch
    string(REGEX REPLACE "^[0-9]+\\.[0-9]+\\.([0-9]+).*" "\\1" VERSION_PATCH "${GIT_COMMIT_ID}")
    string(APPEND PROJECT_VERSION ".${VERSION_PATCH}")

    if(NOT "${GIT_COMMIT_ID_VLIST_COUNT}" STREQUAL "3")
        # no.: optional, used for external components which require 4th version digit (for example openssl)
        string(REGEX REPLACE "^[0-9]+\\.[0-9]+\\.[0-9]+\\.([0-9]+).*" "\\1" VERSION_OPTIONAL "${GIT_COMMIT_ID}")
        string(APPEND PROJECT_VERSION ".${VERSION_OPTIONAL}")

        if(NOT "${GIT_COMMIT_ID_VLIST_COUNT}" STREQUAL "4")
            # string of remaining version digits
            string(REGEX REPLACE "^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+\\.((:?[0-9]+\\.)*[0-9]+).*" "\\1" VERSION_REMAINING "${GIT_COMMIT_ID}")
            message(WARNING "Unexpected number of digits (${GIT_COMMIT_ID_VLIST_COUNT}) in version string '${GIT_COMMIT_ID}', the remaining digits '${VERSION_REMAINING}' will not be included!")
        endif()
    else()
        # no.: optional, used for external components which require 4th version digit (for example openssl)
        set(VERSION_OPTIONAL "0")
    endif()

    string(APPEND PROJECT_VERSION ".${BUILD_ID}")
    # SHA1 string + git 'dirty' flag
    string(REGEX REPLACE "^[0-9]+(:?\\.[0-9]+)+(.*)" "\\1" VERSION_GIT_STATE "${GIT_COMMIT_ID}")
endif()

# stage of build
string(REGEX MATCH "((alpha|beta|rc)[0-9]+)|(rtm|ga)" VERSION_STAGE ${GIT_COMMIT_ID})
if (NOT "${VERSION_STAGE}" STREQUAL "")
    set(STAGE_OF_DEVELOPMENT ${VERSION_STAGE})
endif()

string(APPEND PROJECT_VERSION "${VERSION_GIT_STATE}")
message(STATUS "${PROJECT_NAME}: ${PROJECT_VERSION} (stage: ${STAGE_OF_DEVELOPMENT})")

function(process_config_file PROJECT_NAME INPUT_DIR WORKING_DIR DEPLOYMENT_DIR CONFIG_IN_FILENAMES CONFIG_OUT_FILENAMES)
    string(TIMESTAMP BUILD_TIMESTAMP "%Y-%m-%d")

    foreach(configInFileName configOutFileName IN ZIP_LISTS CONFIG_IN_FILENAMES CONFIG_OUT_FILENAMES)
        message(STATUS "Processing ${PROJECT_NAME} ${configInFileName} file...")

        file(READ ${INPUT_DIR}/${configInFileName}.in inFile_original)
        string(CONFIGURE "${inFile_original}" inFile_updated @ONLY)
        file(WRITE ${WORKING_DIR}/${configInFileName}.tmp "${inFile_updated}")
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${WORKING_DIR}/${configInFileName}.tmp
            ${DEPLOYMENT_DIR}/${configOutFileName}
        )
    endforeach()
endfunction()

function(process_resource_file PROJECT_NAME INPUT_DIR WORKING_DIR DEPLOYMENT_DIR RESOURCE_FILENAME)
    message(STATUS "Processing ${PROJECT_NAME} ${RESOURCE_FILENAME} file...")

    execute_process(
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${INPUT_DIR}/${RESOURCE_FILENAME} ${DEPLOYMENT_DIR}/${RESOURCE_FILENAME}
    )
endfunction()

if(EXISTS ${PROJECT_DIR}/resources/qtifw/packages/meta/package.xml.in AND CMAKE_BUILD_TYPE STREQUAL "OTA")
    process_config_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/packages/meta/ ${WORKING_DIR} ${DEPLOYMENT_DIR}/packages/${PROJECT_BUNDLE_ID}/meta package.xml package.xml)
else()
    process_config_file(${PROJECT_NAME} ${INPUT_DIR} ${WORKING_DIR} ${WORKING_DIR} "${VERSION_IN_FILES}" "${VERSION_OUT_FILES}")
    if(APPLE AND PROJECT_MACBUNDLE)
        process_config_file(${PROJECT_NAME} ${INPUT_DIR} ${WORKING_DIR} ${WORKING_DIR} Info.plist Info.plist)
    elseif(WIN32 AND IS_APP)
        process_config_file(${PROJECT_NAME} ${INPUT_DIR} ${WORKING_DIR} ${WORKING_DIR} App.rc App.rc)
    else()
        message(STATUS "Nothing platform specific to generate on this openrating system.")
    endif()
endif()

if(CMAKE_BUILD_TYPE STREQUAL "OTA")
    if(EXISTS ${PROJECT_DIR}/resources/qtifw/meta/package.xml.in)
        process_config_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/meta/ ${WORKING_DIR} ${DEPLOYMENT_DIR}/packages/${PROJECT_BUNDLE_ID}/meta package.xml package.xml)
    endif()

    file(GLOB files "${PROJECT_DIR}/resources/qtifw/config/*")
    foreach(file ${files})
        get_filename_component(filename ${file} NAME)
        if("${filename}" STREQUAL "config.xml.in")
            set(STRATA_OTA_REPOSITORY_ENABLED $ENV{STRATA_OTA_REPOSITORY_ENABLED})
			set(STRATA_OTA_REPOSITORY $ENV{STRATA_OTA_REPOSITORY})
            set(ApplicationsDirX64 "@ApplicationsDirX64@")
            process_config_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/config ${WORKING_DIR} ${DEPLOYMENT_DIR}/config config.xml config.xml)
        else()
            process_resource_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/config ${WORKING_DIR} ${DEPLOYMENT_DIR}/config ${filename})
        endif()
    endforeach()

    file(GLOB files "${PROJECT_DIR}/resources/qtifw/packages/meta/*license*")
    foreach(file ${files})
        get_filename_component(filename ${file} NAME)
        process_resource_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/packages/meta ${WORKING_DIR} ${DEPLOYMENT_DIR}/packages/${PROJECT_BUNDLE_ID}/meta ${filename})
    endforeach()

    file(GLOB files "${PROJECT_DIR}/resources/qtifw/packages/meta/*.js")
    foreach(file ${files})
        get_filename_component(filename ${file} NAME)
        process_resource_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/packages/meta ${WORKING_DIR} ${DEPLOYMENT_DIR}/packages/${PROJECT_BUNDLE_ID}/meta ${filename})
    endforeach()

    file(GLOB files "${PROJECT_DIR}/resources/qtifw/packages/meta/*.qs")
    foreach(file ${files})
        get_filename_component(filename ${file} NAME)
        process_resource_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/packages/meta ${WORKING_DIR} ${DEPLOYMENT_DIR}/packages/${PROJECT_BUNDLE_ID}/meta ${filename})
    endforeach()

    file(GLOB files "${PROJECT_DIR}/resources/qtifw/packages/meta/*.ui")
    foreach(file ${files})
        get_filename_component(filename ${file} NAME)
        process_resource_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/packages/meta ${WORKING_DIR} ${DEPLOYMENT_DIR}/packages/${PROJECT_BUNDLE_ID}/meta ${filename})
    endforeach()

    file(GLOB files "${PROJECT_DIR}/resources/qtifw/meta/*license*")
    foreach(file ${files})
        get_filename_component(filename ${file} NAME)
        process_resource_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/meta ${WORKING_DIR} ${DEPLOYMENT_DIR}/packages/${PROJECT_BUNDLE_ID}/meta ${filename})
    endforeach()

    file(GLOB files "${PROJECT_DIR}/resources/qtifw/meta/*.js")
    foreach(file ${files})
        get_filename_component(filename ${file} NAME)
        process_resource_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/meta ${WORKING_DIR} ${DEPLOYMENT_DIR}/packages/${PROJECT_BUNDLE_ID}/meta ${filename})
    endforeach()

    file(GLOB files "${PROJECT_DIR}/resources/qtifw/meta/*.qs")
    foreach(file ${files})
        get_filename_component(filename ${file} NAME)
        process_resource_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/meta ${WORKING_DIR} ${DEPLOYMENT_DIR}/packages/${PROJECT_BUNDLE_ID}/meta ${filename})
    endforeach()

    file(GLOB files "${PROJECT_DIR}/resources/qtifw/meta/*.ui")
    foreach(file ${files})
        get_filename_component(filename ${file} NAME)
        process_resource_file(${PROJECT_NAME} ${PROJECT_DIR}/resources/qtifw/meta ${WORKING_DIR} ${DEPLOYMENT_DIR}/packages/${PROJECT_BUNDLE_ID}/meta ${filename})
    endforeach()
endif()
