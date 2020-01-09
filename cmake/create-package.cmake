CMAKE_MINIMUM_REQUIRED(VERSION 3.1)

SET(PACKAGE_CONFIG_CMAKE_IN_CONTENT "@PACKAGE_INIT@

INCLUDE(\"\${CMAKE_CURRENT_LIST_DIR}/@PACKAGE_TARGETS_FILE_NAME@\")
CHECK_REQUIRED_COMPONENTS(@PACKAGE_NAME@)
")

MACRO(INITIALIZE_DEPENDENCY name)
  FIND_PACKAGE(${name} QUIET)
  IF("${name}_FOUND")
    MESSAGE(STATUS "Found system package for ${name}")
  ELSE()
    IF(TARGET ${name})
      MESSAGE(STATUS "Found inherited target ${name}")
    ELSE()
      MESSAGE(STATUS "Initializing ${name} in git submodule")
      EXECUTE_PROCESS(COMMAND "git submodule update --init -- \"external/${name}\""
                      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
      ADD_SUBDIRECTORY("${CMAKE_CURRENT_SOURCE_DIR}/external/${name}" EXCLUDE_FROM_ALL)
    ENDIF()
  ENDIF()
ENDMACRO()

MACRO(MAKE_VARNAME in_str out_var)
  STRING(TOUPPER           "${in_str}"    AS_UPPER    )
  STRING(MAKE_C_IDENTIFIER "${AS_UPPER}"  "${out_var}")
ENDMACRO()

MACRO(PACKAGE_MESSAGE var)
  MESSAGE(STATUS "${var}: ${PACKAGE_${var}}")
ENDMACRO()

FUNCTION(CREATE_PACKAGE_PRINT_HEADER)
  SET(PACKAGE_TITLE_STRING "==  ${PACKAGE_NAME}   -by-   ${PACKAGE_AUTHOR}  ==")
  STRING(LENGTH "${PACKAGE_TITLE_STRING}" PACKAGE_TITLE_STRING_LEN)
  STRING(REPEAT "=" ${PACKAGE_TITLE_STRING_LEN} PACKAGE_TITLE_STRING_SURROUND)
  MESSAGE(STATUS "${PACKAGE_TITLE_STRING_SURROUND}")
  MESSAGE(STATUS "${PACKAGE_TITLE_STRING}")
  MESSAGE(STATUS "${PACKAGE_TITLE_STRING_SURROUND}")
ENDFUNCTION()

FUNCTION(CREATE_PACKAGE_PRINT_VARIABLES)
  # Print relevant variable values
  PACKAGE_MESSAGE(NAME)
  PACKAGE_MESSAGE(AUTHOR)
  PACKAGE_MESSAGE(VERSION)
  PACKAGE_MESSAGE(DEPENDENCIES)
  PACKAGE_MESSAGE(COMPATIBILITY)
  PACKAGE_MESSAGE(NAMESPACE)

  PACKAGE_MESSAGE(INCLUDE_PATH)
  PACKAGE_MESSAGE(HEADERS)
  PACKAGE_MESSAGE(SOURCE_PATH)
  PACKAGE_MESSAGE(SOURCES)
  PACKAGE_MESSAGE(ROOT_DIR)
  PACKAGE_MESSAGE(CMAKE_DIR)
  PACKAGE_MESSAGE(CONFIG_INSTALL_PATH)
  PACKAGE_MESSAGE(HEADERS_INSTALL_PATH)
  PACKAGE_MESSAGE(LIBRARY_INSTALL_PATH)

  PACKAGE_MESSAGE(ABSOLUTE_INCLUDE_PATH)
  PACKAGE_MESSAGE(ABSOLUTE_HEADERS)
  PACKAGE_MESSAGE(ABSOLUTE_SOURCE_PATH)
  PACKAGE_MESSAGE(ABSOLUTE_SOURCES)
ENDFUNCTION()

FUNCTION(CREATE_PACKAGE_PRINT_FOOTER)
  STRING(LENGTH "${PACKAGE_TITLE_STRING}" PACKAGE_TITLE_STRING_LEN)
  STRING(REPEAT "=" ${PACKAGE_TITLE_STRING_LEN} PACKAGE_FOOTER_STRING)
  MESSAGE(STATUS "${PACKAGE_FOOTER_STRING}")
ENDFUNCTION()

MACRO(CREATE_PACKAGE_FULLY_QUALIFY_DIRS path_var_suffix)
  FOREACH(DIR ${PACKAGE_${path_var_suffix}})
    GET_FILENAME_COMPONENT(ABS_DIR "${DIR}" ABSOLUTE BASE_DIR "${PACKAGE_ROOT_DIR}")
    LIST(APPEND PACKAGE_ABSOLUTE_${path_var_suffix} "${ABS_DIR}")
  ENDFOREACH()
ENDMACRO()

MACRO(CREATE_PACKAGE_FULLY_QUALIFY_FILES path_var_suffix files_var_suffix)
  FOREACH(FILE ${PACKAGE_${files_var_suffix}})
    FOREACH(ABS_DIR ${PACKAGE_ABSOLUTE_${path_var_suffix}})
      GET_FILENAME_COMPONENT(ABS_FILE "${FILE}" ABSOLUTE BASE_DIR "${ABS_DIR}")
      IF(ABS_FILE)
        BREAK()
      ENDIF()
    ENDFOREACH()
    LIST(APPEND "PACKAGE_ABSOLUTE_${files_var_suffix}" "${ABS_FILE}")
  ENDFOREACH()
ENDMACRO()

MACRO(CREATE_PACKAGE_CREATE_HEADER_ONLY)
  ADD_LIBRARY(${PACKAGE_NAME} INTERFACE)
  ADD_LIBRARY("${PACKAGE_NAMESPACE}${PACKAGE_NAME}" ALIAS "${PACKAGE_NAME}")

  TARGET_SOURCES(${PACKAGE_NAME}
                 INTERFACE "$<BUILD_INTERFACE:${PACKAGE_ABSOLUTE_HEADERS}>")

  TARGET_INCLUDE_DIRECTORIES(${PACKAGE_NAME}
                             INTERFACE "$<BUILD_INTERFACE:${PACKAGE_ABSOLUTE_INCLUDE_PATH}>")

  TARGET_INCLUDE_DIRECTORIES(${PACKAGE_NAME} SYSTEM INTERFACE
                             "$<INSTALL_INTERFACE:$<INSTALL_PREFIX>/${PACKAGE_HEADERS_INSTALL_PATH}>")

  # Link dependencies
  IF(DEFINED PACKAGE_DEPENDENCIES)
    TARGET_LINK_LIBRARIES(${PACKAGE_NAME} INTERFACE ${PACKAGE_DEPENDENCIES})
  ENDIF()  
ENDMACRO()

MACRO(CREATE_PACKAGE_CREATE_LIBRARY)
  ADD_LIBRARY(${PACKAGE_NAME} ${PACKAGE_TYPE})
  ADD_LIBRARY("${PACKAGE_NAMESPACE}${PACKAGE_NAME}" ALIAS "${PACKAGE_NAME}")

  TARGET_SOURCES(${PACKAGE_NAME}
                 PUBLIC "$<BUILD_INTERFACE:${PACKAGE_ABSOLUTE_HEADERS}>"
                 PRIVATE "${PACKAGE_ABSOLUTE_SOURCES}")

  TARGET_INCLUDE_DIRECTORIES(${PACKAGE_NAME}
                             PUBLIC "$<BUILD_INTERFACE:${PACKAGE_ABSOLUTE_INCLUDE_PATH}>")

  TARGET_INCLUDE_DIRECTORIES(${PACKAGE_NAME} SYSTEM INTERFACE
                             "$<INSTALL_INTERFACE:$<INSTALL_PREFIX>/${PACKAGE_HEADERS_INSTALL_PATH}>")

  # Link dependencies
  IF(DEFINED PACKAGE_DEPENDENCIES)
    TARGET_LINK_LIBRARIES(${PACKAGE_NAME} PUBLIC ${PACKAGE_DEPENDENCIES})
  ENDIF()
ENDMACRO()

MACRO(CREATE_PACKAGE_CREATE_CONFIGURATION)
  # Build package configuration
  INCLUDE(CMakePackageConfigHelpers)

  SET( PACKAGE_CONFIG_EXPORT_NAME ${PACKAGE_NAME}-config               )
  SET(PACKAGE_VERSION_EXPORT_NAME ${PACKAGE_CONFIG_EXPORT_NAME}-version)
  SET(PACKAGE_TARGETS_EXPORT_NAME ${PACKAGE_NAME}-targets              )

  SET( PACKAGE_CONFIG_FILE_NAME   ${PACKAGE_CONFIG_EXPORT_NAME}.cmake )
  SET(PACKAGE_VERSION_FILE_NAME   ${PACKAGE_VERSION_EXPORT_NAME}.cmake)
  SET(PACKAGE_TARGETS_FILE_NAME   ${PACKAGE_TARGETS_EXPORT_NAME}.cmake)

  SET( PACKAGE_CONFIG_BUILD_FILE  "${PROJECT_BINARY_DIR}/${PACKAGE_CONFIG_FILE_NAME}" )
  SET(PACKAGE_VERSION_BUILD_FILE  "${PROJECT_BINARY_DIR}/${PACKAGE_VERSION_FILE_NAME}")
  SET(PACKAGE_TARGETS_BUILD_FILE  "${PROJECT_BINARY_DIR}/${PACKAGE_TARGETS_FILE_NAME}")

  ## we need to find or generate config.cmake.in
  IF(EXISTS "${PACKAGE_CMAKE_DIR}/config.cmake.in")
    SET(PACKAGE_CONFIG_CMAKE_IN_FILE "${PACKAGE_CMAKE_DIR}/config.cmake.in")
  ELSE()
    SET(PACKAGE_CONFIG_CMAKE_IN_FILE "${PACKAGE_CONFIG_BUILD_FILE}.in")
    FILE(WRITE "${PACKAGE_CONFIG_CMAKE_IN_FILE}" "${PACKAGE_CONFIG_CMAKE_IN_CONTENT}")
    MESSAGE(STATUS "File config.cmake.in not found in the cmake directory. Generating a generic version instead.")
  ENDIF()

  CONFIGURE_PACKAGE_CONFIG_FILE("${PACKAGE_CONFIG_CMAKE_IN_FILE}"
                                "${PACKAGE_CONFIG_BUILD_FILE}"
                                INSTALL_DESTINATION "${PACKAGE_CONFIG_INSTALL_PATH}")

  WRITE_BASIC_PACKAGE_VERSION_FILE("${PACKAGE_VERSION_BUILD_FILE}"
                                   VERSION       "${PACKAGE_VERSION}"
                                   COMPATIBILITY "${PACKAGE_COMPATIBILITY}")

  EXPORT(TARGETS      "${PACKAGE_NAME}"
         NAMESPACE    "${PACKAGE_NAMESPACE}"
         FILE         "${PACKAGE_TARGETS_BUILD_FILE}")

  # Install package configuration
  INSTALL(FILES "${PACKAGE_CONFIG_BUILD_FILE}" "${PACKAGE_VERSION_BUILD_FILE}"
          DESTINATION "${PACKAGE_CONFIG_INSTALL_PATH}")

  INSTALL(EXPORT      "${PACKAGE_TARGETS_EXPORT_NAME}"
          DESTINATION "${PACKAGE_CONFIG_INSTALL_PATH}"
          NAMESPACE   "${PACKAGE_NAMESPACE}")
ENDMACRO()

MACRO(CREATE_PACKAGE_EXPORT_VARIABLES)
  # Export the variables
  MACRO(EXPORT_PACKAGE_VAR var)
    SET("${PACKAGE_VARNAME}_${var}" "${PACKAGE_${var}}")
  ENDMACRO()

  EXPORT_PACKAGE_VAR(AUTHOR)
  EXPORT_PACKAGE_VAR(NAMESPACE)
  EXPORT_PACKAGE_VAR(CMAKE_DIR)
  EXPORT_PACKAGE_VAR(CONFIG_INSTALL_PATH)
  EXPORT_PACKAGE_VAR(HEADERS_INSTALL_PATH)
  EXPORT_PACKAGE_VAR(LIBRARY_INSTALL_PATH)
  EXPORT_PACKAGE_VAR(HEADERS)
  EXPORT_PACKAGE_VAR(SOURCES)
  EXPORT_PACKAGE_VAR(DEPENDENCIES)
  EXPORT_PACKAGE_VAR(INCLUDE_PATH)
  EXPORT_PACKAGE_VAR(SOURCE_PATH)
  EXPORT_PACKAGE_VAR(NAME)
  EXPORT_PACKAGE_VAR(VERSION)
  EXPORT_PACKAGE_VAR(ROOT_DIR)
  EXPORT_PACKAGE_VAR(COMPATIBILITY)
  EXPORT_PACKAGE_VAR(ABSOLUTE_HEADERS)
  EXPORT_PACKAGE_VAR(ABSOLUTE_SOURCES)
  EXPORT_PACKAGE_VAR(ABSOLUTE_INCLUDE_PATH)
  EXPORT_PACKAGE_VAR(ABSOLUTE_SOURCE_PATH)
ENDMACRO()
  

MACRO(CREATE_PACKAGE)
  
  # Set parsing meta-arguments
  
  ## Options
  SET(MACRO_OPTIONS)

  ## Keywords with a single value
  SET(MACRO_SINGLE_VALUE_KEYWORDS
      TYPE
      AUTHOR
      NAMESPACE
      CMAKE_DIR
      CONFIG_INSTALL_PATH
      HEADERS_INSTALL_PATH
      LIBRARY_INSTALL_PATH
      NAME
      VERSION
      ROOT_DIR
      COMPATIBILITY
      LIBRARY_TYPE)

  ## Keywords with multiple values
  SET(MACRO_MULTI_VALUE_KEYWORDS
      INCLUDE_PATH
      HEADERS
      SOURCE_PATH
      SOURCES
      DEPENDENCIES
      TARGET_PROPERTIES)

  # Parse arguments
  CMAKE_PARSE_ARGUMENTS(PACKAGE
                        "${MACRO_OPTIONS}"
                        "${MACRO_SINGLE_VALUE_KEYWORDS}"
                        "${MACRO_MULTI_VALUE_KEYWORDS}"
                        ${ARGN})

  # Required arguments
  
  ## AUTHOR
  IF(NOT DEFINED PACKAGE_AUTHOR)
    MESSAGE(FATAL_ERROR "Missing required value for required keyword AUTHOR.")
  ENDIF()

  # Optional arguments (non-dependent)
  ## NAME
  IF(NOT DEFINED PACKAGE_NAME)
    SET(PACKAGE_NAME "${PROJECT_NAME}")
  ENDIF()

  ## VERSION
  IF(NOT DEFINED PACKAGE_VERSION)
    SET(PACKAGE_VERSION "${PROJECT_VERSION}")
  ENDIF()
  
  ## TYPE
  IF((NOT DEFINED PACKAGE_TYPE) AND (NOT PACKAGE_SOURCES))
    SET(PACKAGE_TYPE HEADER)
  ENDIF()

  ## ROOT_DIR
  IF(NOT DEFINED PACKAGE_ROOT_DIR)
    SET(PACKAGE_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
  ENDIF()

  ## COMPATIBILITY
  IF(NOT DEFINED PACKAGE_COMPATIBILITY)
    SET(PACKAGE_COMPATIBILITY "ExactVersion")
  ENDIF()

  # Optional arguments (dependent)
  MAKE_VARNAME(${PACKAGE_NAME}   PACKAGE_VARNAME)
  MAKE_VARNAME(${PACKAGE_AUTHOR} PACKAGE_AUTHOR_VARNAME)

  ## NAMESPACE
  IF(NOT DEFINED PACKAGE_NAMESPACE)
    SET(PACKAGE_NAMESPACE "${PACKAGE_AUTHOR_VARNAME}::")
  ENDIF()

  ## CMAKE_DIR
  IF(NOT DEFINED PACKAGE_CMAKE_DIR)
    SET(PACKAGE_CMAKE_DIR "${PACKAGE_ROOT_DIR}/cmake")
  ENDIF()

  ## CONFIG_INSTALL_PATH
  IF(NOT DEFINED PACKAGE_CONFIG_INSTALL_PATH)
    # FIXME: this will make a mess of everything if we have conflicting package names
    SET(PACKAGE_CONFIG_INSTALL_PATH "lib/cmake/${PACKAGE_NAME}")
  ENDIF()

  ## HEADERS_INSTALL_PATH
  IF(NOT DEFINED PACKAGE_HEADERS_INSTALL_PATH)
    LIST(LENGTH PACKAGE_HEADERS PACKAGE_NUM_HEADERS)
    IF(${PACKAGE_NUM_HEADERS} EQUAL 1)
      SET(PACKAGE_HEADERS_INSTALL_PATH "include/${PACKAGE_AUTHOR}")
    ELSE()
      SET(PACKAGE_HEADERS_INSTALL_PATH "include/${PACKAGE_AUTHOR}/${PACKAGE_NAME}")
    ENDIF()
  ENDIF()

  ## LIBRARY_INSTALL_PATH
  IF(NOT DEFINED PACKAGE_LIBRARY_INSTALL_PATH)
    SET(PACKAGE_LIBRARY_INSTALL_PATH "lib")
  ENDIF()

  ## INCLUDE_PATH
  IF(NOT DEFINED PACKAGE_INCLUDE_PATH)
    SET(PACKAGE_INCLUDE_PATH include)
  ENDIF()

  ## SOURCE_PATH
  IF(NOT DEFINED PACKAGE_SOURCE_PATH)
    SET(PACKAGE_SOURCE_PATH source)
  ENDIF()

  CREATE_PACKAGE_FULLY_QUALIFY_DIRS(INCLUDE_PATH)
  CREATE_PACKAGE_FULLY_QUALIFY_FILES(INCLUDE_PATH HEADERS)
  
  CREATE_PACKAGE_FULLY_QUALIFY_DIRS(SOURCE_PATH)
  CREATE_PACKAGE_FULLY_QUALIFY_FILES(SOURCE_PATH SOURCES)

  CREATE_PACKAGE_PRINT_HEADER()
  CREATE_PACKAGE_PRINT_VARIABLES()

  # Initialize dependencies
  IF(DEFINED PACKAGE_DEPENDENCIES)
    MESSAGE(STATUS "Initializing dependencies")
    FOREACH(DEP ${PACKAGE_DEPENDENCIES})
      INITIALIZE_DEPENDENCY(${DEP})
    ENDFOREACH()
  ENDIF()

  IF(PACKAGE_TYPE STREQUAL HEADER)
    CREATE_PACKAGE_CREATE_HEADER_ONLY()
  ELSE()
    CREATE_PACKAGE_CREATE_LIBRARY()
  ENDIF()

  CREATE_PACKAGE_CREATE_CONFIGURATION()

  # Install targets
  INSTALL(TARGETS     "${PACKAGE_NAME}"
          EXPORT      "${PACKAGE_TARGETS_EXPORT_NAME}"
          DESTINATION "${PACKAGE_LIBRARY_INSTALL_PATH}")

  # Install headers
  INSTALL(FILES "${PACKAGE_ABSOLUTE_HEADERS}"
          DESTINATION "${PACKAGE_HEADERS_INSTALL_PATH}")

  CREATE_PACKAGE_EXPORT_VARIABLES()

  CREATE_PACKAGE_PRINT_FOOTER()
  
ENDMACRO()
