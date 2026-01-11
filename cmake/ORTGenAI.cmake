include(FetchContent)
include(GNUInstallDirs)

set(cmd_wrapper)
string(REGEX MATCH "^Visual Studio" VISUAL_STUDIO_GENERATOR ${CMAKE_GENERATOR})
string(COMPARE EQUAL "Visual Studio" ${VISUAL_STUDIO_GENERATOR} USING_MSVSTUDIO)

string(REGEX MATCH "^Ninja" NINJA_GENRATOR ${CMAKE_GENERATOR})
string(COMPARE EQUAL "Ninja" ${NINJA_GENRATOR} USING_NINJA)

string(REGEX MATCH "Makefiles$" MAKEFILES_GENRATOR ${CMAKE_GENERATOR})
string(COMPARE EQUAL "Makefiles" ${MAKEFILES_GENRATOR} USING_MAKEFILES)

if(USING_MSVSTUDIO)
#################### MSVC vcvars
FetchContent_Declare(
  find-vcvars
  GIT_REPOSITORY 		 https://github.com/scikit-build/cmake-FindVcvars.git
  GIT_TAG        		 origin/master
  GIT_SHALLOW 			 TRUE
  GIT_SUBMODULES_RECURSE TRUE
  
  EXCLUDE_FROM_ALL
)

FetchContent_Populate(find-vcvars)

file(REAL_PATH ${find-vcvars_SOURCE_DIR} FINDVCVARS_SOURCE_DIR)

list(INSERT CMAKE_MODULE_PATH 0 ${FINDVCVARS_SOURCE_DIR})


if(MSVC)
  set(Vcvars_MSVC_ARCH 64)
  set(Vcvars_FIND_VCVARSALL TRUE)
  find_package(Vcvars REQUIRED)
  set(cmd_wrapper ${Vcvars_LAUNCHER})
endif()
endif()

###################### onnxruntime
FetchContent_Declare(
  ort_project
  GIT_REPOSITORY 		 https://github.com/sheldonrobinson/onnxruntime.git
  GIT_TAG        		 origin/main
  GIT_SHALLOW 			 TRUE
  GIT_SUBMODULES_RECURSE TRUE

  EXCLUDE_FROM_ALL
)

FetchContent_Populate(ort_project)

file(REAL_PATH ${ort_project_SOURCE_DIR} ORT_SOURCE_DIR)
file(REAL_PATH ${ort_project_BINARY_DIR} ORT_BINARY_DIR)

file(TO_NATIVE_PATH ${ORT_SOURCE_DIR} ORT_BUILD_SRC_DIR)
file(TO_NATIVE_PATH "tools/ci_build/build.py" ORT_BUILD_PY)
file(TO_NATIVE_PATH ${CMAKE_INSTALL_PREFIX} ORT_BUILD_BINARY_DIR)

set(ORT_BUILD_PROJECT_DIR "${ORT_SOURCE_DIR}/$<CONFIG>")

set(ORT_HOME ${CMAKE_INSTALL_PREFIX})
set(ORT_BUILD_DIR ${ORT_SOURCE_DIR}/$<CONFIG>)

set(ORT_LIB_DIR "${ORT_HOME}/lib")
set(ORT_BIN_DIR "${ORT_HOME}/bin")
set(ORT_INC_DIR "${ORT_HOME}/include")
set(ORT_HDRS_DIR "${ORT_HOME}/include/onnxruntime")

set(ORT_BINARY_NAME "$<$<NOT:$<PLATFORM_ID:Windows>>:lib>onnxruntime.$<$<PLATFORM_ID:Windows,CYGWIN,MSYS,WindowsStore>:dll>$<$<PLATFORM_ID:Darwin,iOS>:dynlib>$<$<PLATFORM_ID:Android,Linux,DragonFly,FreeBSD,NetBSD,OpenBSD>:so>")
set(ORT_PROVIDERS_BINARY_NAME "$<$<NOT:$<PLATFORM_ID:Windows>>:lib>onnxruntime_providers_shared.$<$<PLATFORM_ID:Windows,CYGWIN,MSYS,WindowsStore>:dll>$<$<PLATFORM_ID:Darwin,iOS>:dynlib>$<$<PLATFORM_ID:Android,Linux,DragonFly,FreeBSD,NetBSD,OpenBSD>:so>")

set(ORT_LINK_LIBRARY_NAME "$<$<NOT:$<PLATFORM_ID:Windows>>:lib>onnxruntime.$<$<PLATFORM_ID:Windows,CYGWIN,MSYS,WindowsStore>:lib>$<$<PLATFORM_ID:Darwin,iOS>:dynlib>$<$<PLATFORM_ID:Android,Linux,DragonFly,FreeBSD,NetBSD,OpenBSD>:so>")
set(ORT_PROVIDERS_LINK_LIBRARY_NAME "$<$<NOT:$<PLATFORM_ID:Windows>>:lib>onnxruntime_providers_shared.$<$<PLATFORM_ID:Windows,CYGWIN,MSYS,WindowsStore>:lib>$<$<PLATFORM_ID:Darwin,iOS>:dynlib>$<$<PLATFORM_ID:Android,Linux,DragonFly,FreeBSD,NetBSD,OpenBSD>:so>")


set(ORT_OUTPUT_BINPATH "${ORT_BUILD_SRC_DIR}/$<CONFIG>/$<CONFIG>/${ORT_BINARY_NAME}")
set(ORT_OUTPUT_PROVIDERS_BINPATH "${ORT_BUILD_SRC_DIR}/$<CONFIG>/$<CONFIG>/${ORT_PROVIDERS_BINARY_NAME}")
set(ORT_OUTPUT_IMPORTLIBPATH "${ORT_BUILD_SRC_DIR}/$<CONFIG>/$<CONFIG>/${ORT_LINK_LIBRARY_NAME}")
set(ORT_OUTPUT_PROVIDERS_IMPORTLIBPATH "${ORT_BUILD_SRC_DIR}/$<CONFIG>/$<CONFIG>/${ORT_PROVIDERS_LINK_LIBRARY_NAME}")


set(ORT_BUILD_BINPATH "${ORT_HOME}/bin/${ORT_BINARY_NAME}")
set(ORT_BUILD_PROVIDERS_BINPATH "${ORT_HOME}/bin/${ORT_PROVIDERS_BINARY_NAME}")
set(ORT_BUILD_IMPORTLIBPATH "${ORT_HOME}/lib/${ORT_BINARY_NAME}")
set(ORT_BUILD_PROVIDERS_IMPORTLIBPATH "${ORT_HOME}/lib/onnxruntime_providers_shared.lib")

add_custom_command(OUTPUT ${ORT_OUTPUT_BINPATH}
						  ${ORT_OUTPUT_PROVIDERS_BINPATH}
						  ${ORT_OUTPUT_IMPORTLIBPATH}
						  ${ORT_OUTPUT_PROVIDERS_IMPORTLIBPATH}
				   COMMAND ${Python_EXECUTABLE} ${ORT_BUILD_PY} 
											 --cmake_generator ${CMAKE_GENERATOR}
											 --build_dir ${ORT_BUILD_SRC_DIR}
											 --config $<CONFIG> 
											 --build_shared_lib 
											 --use_mimalloc 
											 --use_full_protobuf
											 --use_dml
											 --use_binskim_compliant_compile_flags
											 --compile_no_warning_as_error 
											 --parallel
											 --skip_submodule_sync
											 --skip_tests 
											 --skip_winml_tests 
											 --cmake_extra_defines CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
				   WORKING_DIRECTORY ${ORT_BUILD_SRC_DIR}
				   COMMAND_EXPAND_LISTS
				   USES_TERMINAL
				   VERBATIM)

if(USING_MSVSTUDIO)
add_custom_target(ort_install ALL ${cmd_wrapper} msbuild Install.vcxproj -property:Configuration=$<CONFIG>
				DEPENDS ${ORT_OUTPUT_BINPATH}
						${ORT_OUTPUT_PROVIDERS_BINPATH}
						${ORT_OUTPUT_IMPORTLIBPATH}
						${ORT_OUTPUT_PROVIDERS_IMPORTLIBPATH}
				BYPRODUCTS	${ORT_BUILD_BINPATH}
							${ORT_BUILD_PROVIDERS_BINPATH}
							${ORT_BUILD_IMPORTLIBPATH}
							${ORT_BUILD_PROVIDERS_IMPORTLIBPATH}
				WORKING_DIRECTORY ${ORT_BUILD_PROJECT_DIR}
				COMMENT "Running generated ort install batch script..."
				COMMAND_EXPAND_LISTS
				VERBATIM
				USES_TERMINAL)
endif()

if(USING_NINJA)
add_custom_target(ort_install ALL ${cmd_wrapper} ninja install --config $<CONFIG>
				DEPENDS ${ORT_OUTPUT_BINPATH}
						${ORT_OUTPUT_PROVIDERS_BINPATH}
						${ORT_OUTPUT_IMPORTLIBPATH}
						${ORT_OUTPUT_PROVIDERS_IMPORTLIBPATH}
				BYPRODUCTS	${ORT_BUILD_BINPATH}
							${ORT_BUILD_PROVIDERS_BINPATH}
							${ORT_BUILD_IMPORTLIBPATH}
							${ORT_BUILD_PROVIDERS_IMPORTLIBPATH}
				WORKING_DIRECTORY ${ORT_BUILD_PROJECT_DIR}
				COMMENT "Running generated ort install batch script..."
				COMMAND_EXPAND_LISTS
				VERBATIM
				USES_TERMINAL)
endif()

if(USING_MAKEFILES)
add_custom_target(ort_install ALL ${cmd_wrapper} make install
				DEPENDS ${ORT_OUTPUT_BINPATH}
						${ORT_OUTPUT_PROVIDERS_BINPATH}
						${ORT_OUTPUT_IMPORTLIBPATH}
						${ORT_OUTPUT_PROVIDERS_IMPORTLIBPATH}
				BYPRODUCTS	${ORT_BUILD_BINPATH}
							${ORT_BUILD_PROVIDERS_BINPATH}
							${ORT_BUILD_IMPORTLIBPATH}
							${ORT_BUILD_PROVIDERS_IMPORTLIBPATH}
				WORKING_DIRECTORY ${ORT_BUILD_PROJECT_DIR}
				COMMENT "Running generated ort install batch script..."
				COMMAND_EXPAND_LISTS
				VERBATIM
				USES_TERMINAL)
endif()


add_library(ort SHARED IMPORTED GLOBAL)
add_dependencies(ort ort_install)
list(APPEND ORT_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${ORT_BINARY_DIR}/include> $<BUILD_INTERFACE:${ORT_BINARY_DIR}/include/onnxruntime>)
# list(APPEND ORT_BUILD_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${ORT_BINARY_DIR}/include> $<BUILD_INTERFACE:${ORT_BINARY_DIR}/include/onnxruntime>)
set_target_properties(# Specifies the target library.
                       ort
                       PROPERTIES 
					   IMPORTED_LOCATION			 ${ORT_BUILD_BINPATH}
					   IMPORTED_IMPLIB				 ${ORT_BUILD_IMPORTLIBPATH}
					   INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${ORT_BINARY_DIR}/include> $<BUILD_INTERFACE:${ORT_BINARY_DIR}/include/onnxruntime>
					 )
if (MSVC)
	set_target_properties(ort PROPERTIES 
				PDB_OUTPUT_DIRECTORY $<INSTALL_INTERFACE:${ORT_BUILD_DIR}/$<CONFIG>>
				)
endif()

add_library(onnxruntime_providers_shared SHARED IMPORTED GLOBAL)
add_dependencies(onnxruntime_providers_shared ort_install)
set_target_properties(# Specifies the target library.
                       onnxruntime_providers_shared
                       PROPERTIES 
					   IMPORTED_LOCATION	${ORT_BUILD_PROVIDERS_BINPATH}
					   IMPORTED_IMPLIB		${ORT_BUILD_PROVIDERS_IMPORTLIBPATH}
					 )
if (MSVC)
	set_target_properties(onnxruntime_providers_shared PROPERTIES 
				PDB_OUTPUT_DIRECTORY $<INSTALL_INTERFACE:${ORT_BUILD_DIR}/$<CONFIG>>
				)
endif()

################## nlohmann
FetchContent_Declare(
  nlohmann_json
  GIT_REPOSITORY 		 https://github.com/nlohmann/json.git
  GIT_TAG        		 v3.12.0
  GIT_SHALLOW 			 TRUE
  GIT_SUBMODULES_RECURSE TRUE
  
  EXCLUDE_FROM_ALL
  
  OVERRIDE_FIND_PACKAGE
)

set(JSON_BuildTests OFF CACHE BOOL "Build the unit tests when BUILD_TESTING is enabled." FORCE)
set(JSON_CI OFF CACHE BOOL "Enable CI build targets." FORCE)
set(JSON_Diagnostics OFF CACHE BOOL  "Use extended diagnostic messages." FORCE)
set(JSON_Diagnostic_Positions OFF CACHE BOOL "Enable diagnostic positions." FORCE)
set(JSON_GlobalUDLs ON CACHE BOOL "Place user-defined string literals in the global namespace." FORCE)
set(JSON_ImplicitConversions ON CACHE BOOL "Enable implicit conversions." FORCE)
set(JSON_DisableEnumSerialization OFF CACHE BOOL "Disable default integer enum serialization." FORCE)
set(JSON_LegacyDiscardedValueComparison OFF CACHE BOOL "Enable legacy discarded value comparison." FORCE)
set(JSON_Install OFF CACHE BOOL "Install CMake targets during install step." FORCE)
set(JSON_MultipleHeaders ON CACHE BOOL "Use non-amalgamated version of the library." FORCE)
set(JSON_SystemInclude OFF CACHE BOOL "Include as system headers (skip for clang-tidy)." FORCE)

FetchContent_MakeAvailable(nlohmann_json)

file(REAL_PATH ${nlohmann_json_SOURCE_DIR} NLOHMANN_JSON_SOURCE_DIR)

if(NOT TARGET nlohmann::json)
	add_library(nlohmann::json INTERFACE IMPORTED)
    set_target_properties(nlohmann::json PROPERTIES
                          INTERFACE_LINK_LIBRARIES nlohmann_json 							  
						  INTERFACE_POSITION_INDEPENDENT_CODE ON
						  )
endif()

################### argparse
FetchContent_Declare(
  argparse
  GIT_REPOSITORY 		 https://github.com/p-ranav/argparse.git
  GIT_TAG        		 v3.2
  GIT_SHALLOW 			 TRUE

  EXCLUDE_FROM_ALL

  OVERRIDE_FIND_PACKAGE
)

FetchContent_MakeAvailable(argparse)

if(NOT TARGET argparse::argparse)
	add_library(argparse::argparse INTERFACE IMPORTED)
    set_target_properties(argparse::argparse PROPERTIES
                          INTERFACE_LINK_LIBRARIES argparse 							  
						  INTERFACE_POSITION_INDEPENDENT_CODE ON
						  )
endif()

################### cpp-httplib
FetchContent_Declare(
  cpp-httplib
  GIT_REPOSITORY 		 https://github.com/yhirose/cpp-httplib.git
  GIT_TAG        		 v0.29.0
  GIT_SHALLOW 			 TRUE
  
  EXCLUDE_FROM_ALL
  
  OVERRIDE_FIND_PACKAGE
)

FetchContent_MakeAvailable(cpp-httplib)

if(NOT TARGET httplib::httplib)
	add_library(httplib::httplib INTERFACE IMPORTED)
    set_target_properties(httplib::httplib PROPERTIES
                          INTERFACE_LINK_LIBRARIES httplib 							  
						  INTERFACE_POSITION_INDEPENDENT_CODE ON
						  )
endif()


###################### ortgenai
# Debug build broken missing reference to _imp__calloc_dbg, __imp__free_dbg, __imp__malloc_dbg, and __imp__CrtDbgReport 
FetchContent_Declare(
  oga_project
  GIT_REPOSITORY 		 https://github.com/sheldonrobinson/onnxruntime-genai.git
  GIT_TAG        		 origin/main
  GIT_SHALLOW 			 TRUE
  GIT_SUBMODULES_RECURSE TRUE

  EXCLUDE_FROM_ALL
)

FetchContent_Populate(oga_project)

file(REAL_PATH ${oga_project_SOURCE_DIR} OGA_SOURCE_DIR)
file(REAL_PATH ${oga_project_BINARY_DIR} OGA_BINARY_DIR)

file(TO_NATIVE_PATH ${ORT_HOME} OGA_ORT_HOME)
file(TO_NATIVE_PATH ${OGA_SOURCE_DIR} OGA_BUILD_SRC_DIR)
file(TO_NATIVE_PATH "build.py" OGA_BUILD_PY)

file(TO_NATIVE_PATH ${OGA_BINARY_DIR} OGA_BUILD_BINARY_DIR)

set(OGA_BUILD_PROJECT_DIR "${OGA_SOURCE_DIR}/Release")

set(OGA_BINARY_NAME "$<$<NOT:$<PLATFORM_ID:Windows>>:lib>onnxruntime-genai.$<$<PLATFORM_ID:Windows,CYGWIN,MSYS,WindowsStore>:dll>$<$<PLATFORM_ID:Darwin,iOS>:dynlib>$<$<PLATFORM_ID:Android,Linux,DragonFly,FreeBSD,NetBSD,OpenBSD>:so>")
set(OGA_LINK_LIBRARY_NAME "$<$<NOT:$<PLATFORM_ID:Windows>>:lib>onnxruntime-genai.$<$<PLATFORM_ID:Windows,CYGWIN,MSYS,WindowsStore>:lib>$<$<PLATFORM_ID:Darwin,iOS>:dynlib>$<$<PLATFORM_ID:Android,Linux,DragonFly,FreeBSD,NetBSD,OpenBSD>:so>")

set(OGA_SLN_FILE "${OGA_SOURCE_DIR}/Release/Generators.sln")
set(OGA_OUTPUT_BINPATH "${OGA_BUILD_PROJECT_DIR}/Release/${OGA_BINARY_NAME}")
set(OGA_OUTPUT_IMPORTLIBPATH "${OGA_BUILD_PROJECT_DIR}/Release/${OGA_LINK_LIBRARY_NAME}")

set(OGA_HOME ${OGA_BINARY_DIR})
set(OGA_SOURCE_DIR ${OGA_SOURCE_DIR})

set(OGA_BUILD_BINPATH "${OGA_HOME}/lib/${OGA_BINARY_NAME}")
set(OGA_BUILD_IMPORTLIBPATH "${OGA_HOME}/lib/OGA_LINK_LIBRARY_NAME")

add_custom_command(OUTPUT ${OGA_SLN_FILE}
				   COMMAND ${Python_EXECUTABLE} ${OGA_BUILD_PY}
											 --update
											 --cmake_generator ${CMAKE_GENERATOR}
											 --build_dir ${OGA_BUILD_SRC_DIR} 
											 --config Release
											 --use_dml
											 --use_guidance
											 --parallel
											 --skip_examples
											 --skip_tests
											 --skip_wheel
											 --ort_home ${OGA_ORT_HOME}
											 --cmake_extra_defines CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} USE_WINML=OFF ONNXRUNTIME_LIB=onnxruntime.lib ZLIB_LIBRARY=${ZLIB_LIBRARY} ZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR}
				   WORKING_DIRECTORY ${OGA_SOURCE_DIR}
				   COMMAND_EXPAND_LISTS
				   USES_TERMINAL
				   VERBATIM)

add_custom_command(OUTPUT ${OGA_OUTPUT_BINPATH}
						  ${OGA_OUTPUT_IMPORTLIBPATH}
				   COMMAND ${Python_EXECUTABLE} ${OGA_BUILD_PY}
											 --build
											 --cmake_generator ${CMAKE_GENERATOR}
											 --build_dir ${OGA_BUILD_SRC_DIR} 
											 --config Release 
											 --use_dml
											 --use_guidance
											 --parallel
											 --skip_examples
											 --skip_tests
											 --skip_wheel
											 --ort_home ${OGA_ORT_HOME}
											 --cmake_extra_defines CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} USE_WINML=OFF ONNXRUNTIME_LIB=onnxruntime.lib ZLIB_LIBRARY=${ZLIB_LIBRARY} ZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR}
				   DEPENDS ${OGA_SLN_FILE}					 
				   WORKING_DIRECTORY ${OGA_SOURCE_DIR}
				   COMMAND_EXPAND_LISTS
				   USES_TERMINAL
				   VERBATIM)
 
add_custom_target(oga_install ALL ${cmd_wrapper} msbuild Install.vcxproj -property:Configuration=Release
				  DEPENDS ${OGA_OUTPUT_BINPATH}
						  ${OGA_OUTPUT_IMPORTLIBPATH}
				  BYPRODUCTS ${OGA_BUILD_BINPATH}
							 ${OGA_BUILD_IMPORTLIBPATH}
				  WORKING_DIRECTORY ${OGA_BUILD_PROJECT_DIR}
				  COMMENT "Running generated oga install batch script..."
				  COMMAND_EXPAND_LISTS
				  VERBATIM
				  USES_TERMINAL)

add_dependencies(oga_install ort_install)
################### build ort-genai
set(OGA_LIB_DIR "${OGA_HOME}/lib")
set(OGA_BIN_DIR "${OGA_HOME}/bin")
set(OGA_INC_DIR "${OGA_HOME}/include")
set(OGA_HDRS_DIR "${OGA_HOME}/include")
list(APPEND OGA_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${OGA_BINARY_DIR}/include> ${ORT_INCLUDE_DIRECTORIES})
if(NOT TARGET ort-genai)
	add_library(ort-genai SHARED IMPORTED GLOBAL)
	add_dependencies(ort-genai oga_install)
	set_target_properties(# Specifies the target library.
						   ort-genai
						   PROPERTIES 
						   IMPORTED_LOCATION ${OGA_BUILD_BINPATH}
						   IMPORTED_IMPLIB ${OGA_BUILD_IMPORTLIBPATH}
						   INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${OGA_BINARY_DIR}/include>
						 )
	if (MSVC)
		set_target_properties(ort-genai PROPERTIES 
					PDB_OUTPUT_DIRECTORY $<INSTALL_INTERFACE:${OGA_BUILD_PROJECT_DIR}>
					)
	endif()
endif()

###################### slmengine configuration

include_directories(${OGA_HOME}/include ${ORT_HOME}/include ${ORT_HOME}/include/onnxruntime)

####################### eigen
set(BUILD_TESTING OFF CACHE BOOL "Enable creation of tests." FORCE)
set(EIGEN_BUILD_TESTING OFF CACHE BOOL "Enable creation of Eigen tests." FORCE)
set(EIGEN_LEAVE_TEST_IN_ALL_TARGET OFF CACHE BOOL "Leaves tests in the all target, needed by ctest for automatic building." FORCE)
set(EIGEN_BUILD_BLAS OFF CACHE BOOL "Toggles the building of the Eigen Blas library" FORCE)
set(EIGEN_BUILD_LAPACK OFF CACHE BOOL "Toggles the building of the included Eigen LAPACK library" FORCE)
set(EIGEN_BUILD_DOC OFF CACHE BOOL "Enable creation of Eigen documentation" FORCE)
set(EIGEN_BUILD_DEMOS OFF CACHE BOOL "Toggles the building of the Eigen demos" FORCE)
set(EIGEN_BUILD_CMAKE_PACKAGE OFF CACHE BOOL "Enables the creation of EigenConfig.cmake and related files" FORCE)

####################### onnxruntime
set(USE_CUDA OFF CACHE BOOL "Build with CUDA support" FORCE)
set(USE_TRT_RTX OFF CACHE BOOL "Build with TensorRT-RTX support" FORCE)
set(USE_ROCM OFF CACHE BOOL "Build with ROCm support" FORCE)
set(USE_DML ON CACHE BOOL "Build with DML support" FORCE)
set(USE_WINML OFF CACHE BOOL "Build with WinML support" FORCE)
set(USE_GUIDANCE ON CACHE BOOL "Build with guidance support" FORCE)

set(ARTIFACTS_DIR ${OGA_HOME} CACHE PATH "ort-genai home" FORCE)
add_subdirectory("${OGA_SOURCE_DIR}/examples/slm_engine/src" "${CMAKE_CURRENT_BINARY_DIR}/slm_engine")

add_dependencies(slmengine ort-genai argparse::argparse nlohmann::json)
add_dependencies(input_decoder-test ort-genai argparse::argparse nlohmann::json)

add_dependencies(slm-server ort-genai zlib argparse::argparse nlohmann::json)
add_dependencies(slm-runner ort-genai zlib argparse::argparse nlohmann::json)
add_dependencies(unit-test ort-genai zlib argparse::argparse nlohmann::json)

set(SLMENGINE_BINARY_NAME "$<$<NOT:$<PLATFORM_ID:Windows>>:lib>slmengine.$<$<PLATFORM_ID:Windows,CYGWIN,MSYS,WindowsStore>:dll>$<$<PLATFORM_ID:Darwin,iOS>:dynlib>$<$<PLATFORM_ID:Android,Linux,DragonFly,FreeBSD,NetBSD,OpenBSD>:so>")
set(SLMENGINE_LINK_LIBRARY_NAME "$<$<NOT:$<PLATFORM_ID:Windows>>:lib>slmengine.$<$<PLATFORM_ID:Windows,CYGWIN,MSYS,WindowsStore>:lib>$<$<PLATFORM_ID:Darwin,iOS>:dynlib>$<$<PLATFORM_ID:Android,Linux,DragonFly,FreeBSD,NetBSD,OpenBSD>:so>")

set(SLMENGINE_BUILD_BINPATH "${CMAKE_CURRENT_BINARY_DIR}/slm_engine/cpp/${SLMENGINE_BINARY_NAME}")
set(SLMENGINE_BUILD_IMPORTLIBPATH "${CMAKE_CURRENT_BINARY_DIR}/slm_engine/cpp/$<CONFIG>/${SLMENGINE_LINK_LIBRARY_NAME}")

if(NOT TARGET slm_engine)
	add_library(slm_engine SHARED IMPORTED GLOBAL)
    set_target_properties(slm_engine PROPERTIES
                          INTERFACE_LINK_LIBRARIES 
							  slmengine
						  IMPORTED_LOCATION ${SLMENGINE_BUILD_BINPATH}
					      IMPORTED_IMPLIB ${SLMENGINE_BUILD_IMPORTLIBPATH}
						  INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${OGA_SOURCE_DIR}/examples/slm_engine/src/cpp>
						  INTERFACE_POSITION_INDEPENDENT_CODE ON
						  )
	if (MSVC)
		set_target_properties(slm_engine PROPERTIES 
					PDB_OUTPUT_DIRECTORY $<INSTALL_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/slm_engine/cpp/$<CONFIG>>
					)
	endif()
endif()