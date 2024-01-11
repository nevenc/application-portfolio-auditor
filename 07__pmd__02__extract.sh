#!/usr/bin/env bash
# Copyright 2019-2024 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

##############################################################################################################
# Extract key results from the reports generated by ...
#   "PMD" - https://pmd.github.io/
##############################################################################################################

# ----- Please adjust

# ------ Do not modify
SEPARATOR=","
STEP=$(get_step)
APP_DIR_OUT=${REPORTS_DIR}/${STEP}__PMD
PMD_DIR_OUT=${APP_DIR_OUT}/pmd
CPD_DIR_OUT=${APP_DIR_OUT}/cpd
export LOG_FILE=${APP_DIR_OUT}.log

declare -A LANGUAGES=(
	["java-src"]="Java"
	["js"]="JavaScript"
	["python"]="Python"
	["cs"]="C#"
)

function extract() {

	GROUP=${1}
	RESULT_FILE=${2}

	while read -r APP; do
		APP_NAME=$(basename "${APP}")
		log_extract_message "app '${APP_NAME}'"

		LANGUAGE="Other"
		for EXT in "${!LANGUAGES[@]}"; do
			if grep -q "${APP}" "${REPORTS_DIR}/list__${GROUP}__${EXT}.txt"; then
				LANGUAGE="${LANGUAGES[$EXT]}"
				break
			fi
		done

		declare COUNT_VIOLATIONS COUNT_RULES
		COUNT_VIOLATIONS='n/a'
		COUNT_RULES='n/a'
		if [[ "${LANGUAGE}" == "Java" ]]; then
			PMD_FILE=${PMD_DIR_OUT}/${GROUP}__${APP_NAME}_pmd.html
			if [[ -f "${PMD_FILE}" ]]; then
				COUNT_VIOLATIONS=$(awk 'BEGIN { count=0 } /<td align="center">[0-9]*<\/td>/{count++} END{print count}' "${PMD_FILE}" || true)
				COUNT_RULES=$(awk -F'[<>]' 'BEGIN { count=0 } /<tr><td>[^<]*<\/td><td align=center>[0-9]*<\/td><\/tr>/ {count++} END {print count}' "${PMD_FILE}" || true)
			fi
			#echo "${APP_NAME} - VIOLATIONS: ${COUNT_VIOLATIONS} - RULES: ${COUNT_RULES}"
		fi

		CPD_FILE=${CPD_DIR_OUT}/${GROUP}__${APP_NAME}__cpd.xml

		declare COUNT_DUPLICATED_FRAMENTS TOTAL_DUPLICATED_LINES TOTAL_DUPLICATED_TOKENS
		if [[ -f "${CPD_FILE}" ]]; then
			TOTAL_DUPLICATED_LINES=0
			TOTAL_DUPLICATED_TOKENS=0
			COUNT_DUPLICATED_FRAMENTS=$(awk 'BEGIN { count=0 } /<duplication lines="/ { count++ } END { print count }' "${CPD_FILE}" || true)
			LINES=0
			TOKENS=0
			FIRST="true"
			while IFS='' read -r LINE; do
				#echo ${LINE}
				if [[ "${LINE}" == *'<duplication lines="'* ]]; then
					# shellcheck disable=SC2001
					LINES=$(echo "${LINE}" | sed 's/<duplication lines="\([^"]*\)".*/\1/')
					# shellcheck disable=SC2001
					TOKENS=$(echo "${LINE}" | sed 's/.*tokens="\([^"]*\)">.*/\1/')
					FIRST="true"
					#echo "LINES: $LINES  -  TOKENS: $TOKENS"
				elif [[ "${LINE}" =~ \<file\ [a-z]*\=\" ]]; then
					if [[ "${FIRST}" == "true" ]]; then
						FIRST="false"
					else
						# Counting duplicates from the second occurence
						TOTAL_DUPLICATED_LINES=$((TOTAL_DUPLICATED_LINES + LINES))
						TOTAL_DUPLICATED_TOKENS=$((TOTAL_DUPLICATED_TOKENS + TOKENS))
						#echo "TOTAL_DUPLICATED_LINES: ${TOTAL_DUPLICATED_LINES}  -  TOTAL_DUPLICATED_TOKENS: ${TOTAL_DUPLICATED_TOKENS}"
					fi
				fi
			done < <(awk '/<duplication lines="|<file [a-z]*=/' "${CPD_FILE}")
		else
			COUNT_DUPLICATED_FRAMENTS='n/a'
			TOTAL_DUPLICATED_LINES='n/a'
			TOTAL_DUPLICATED_TOKENS='n/a'
		fi

		#echo "${APP_NAME} - DUPLICATED FRAGMENTS: ${COUNT_DUPLICATED_FRAMENTS} - LINES: ${TOTAL_DUPLICATED_LINES} - TOKENS: ${TOTAL_DUPLICATED_TOKENS}"
		echo "${APP_NAME}${SEPARATOR}${COUNT_RULES}${SEPARATOR}${COUNT_VIOLATIONS}${SEPARATOR}${COUNT_DUPLICATED_FRAMENTS}${SEPARATOR}${TOTAL_DUPLICATED_LINES}${SEPARATOR}${TOTAL_DUPLICATED_TOKENS}" >>"${RESULT_FILE}"

	done <"${REPORTS_DIR}/list__${GROUP}__all_apps.txt"
}

function extract_group() {
	GROUP=$(basename "${1}")
	RESULT_FILE="${APP_DIR_OUT}/${GROUP}___results_extracted.csv"

	if [[ -d "${APP_DIR_OUT}" ]]; then
		rm -f "${RESULT_FILE}"
		touch "${RESULT_FILE}"

		log_extract_message "group '${GROUP}'"
		extract "${GROUP}" "${RESULT_FILE}"

		# Adding the header
		{
			echo "Applications${SEPARATOR}PMD rules triggered${SEPARATOR}PMD violations${SEPARATOR}Copy-pasted fragments${SEPARATOR}Copy-pasted lines${SEPARATOR}Copy-pasted tokens"
			cat "${RESULT_FILE}"
		} >"${RESULT_FILE}.tmp"
		mv "${RESULT_FILE}.tmp" "${RESULT_FILE}"
	else
		LOG_FILE=/dev/null
		log_console_error "PMD result directory does not exist: ${APP_DIR_OUT}"
		return
	fi
}

function main() {
	for_each_group extract_group
}

main
