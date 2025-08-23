#!/usr/bin/env python3
"""
Script to parse 20011.txt file and extract all [_line] entries.
Creates a CSV spreadsheet with columns: Type, String1_Name, Matching_Filters, 20011_Line_Number, Style_Line_Number, Full_Entry
"""

import csv
import re

def parse_style_lines(filename):
    """Parse the my-style/lines file and extract type codes with their filters and line numbers."""
    type_filters = {}

    with open(filename, 'r', encoding='utf-8', errors='ignore') as file:
        lines = file.readlines()

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        start_line_number = i + 1  # Line numbers are 1-indexed

        # Skip comments and empty lines
        if line.startswith('#') or not line:
            i += 1
            continue

        # Start building a multi-line rule
        rule_lines = [line]
        current_line = line

        # Continue reading lines until we find a closing bracket or end of file
        i += 1
        while i < len(lines):
            next_line = lines[i].strip()

            # Skip comments
            if next_line.startswith('#'):
                i += 1
                continue

            # If it's an empty line, continue
            if not next_line:
                i += 1
                continue

            # Add this line to our rule
            rule_lines.append(next_line)
            current_line = next_line

            # Check if this line ends with a closing bracket (either } or ])
            if current_line.endswith('}') or current_line.endswith(']'):
                break

            i += 1

        # Now we have a complete rule (possibly multi-line)
        complete_rule = ' '.join(rule_lines)

        # Look for type codes in square brackets
        bracket_match = re.search(r'\[(0x[0-9a-fA-F]+)[^\]]*\]', complete_rule)
        if bracket_match:
            type_code = bracket_match.group(1)

            # Extract the filter part (everything before the first { or [)
            filter_part = complete_rule
            if '{' in complete_rule:
                filter_part = complete_rule[:complete_rule.find('{')].strip()
            elif '[' in complete_rule:
                filter_part = complete_rule[:complete_rule.find('[')].strip()

            # Clean up the filter
            filter_part = filter_part.strip()

            if filter_part:
                if type_code in type_filters:
                    type_filters[type_code].append((filter_part, start_line_number))
                else:
                    type_filters[type_code] = [(filter_part, start_line_number)]

        i += 1

    return type_filters

def parse_20011_lines(filename):
    """Parse the 20011.txt file and extract all [_line] entries with line numbers."""
    lines_data = []

    with open(filename, 'r', encoding='utf-8', errors='ignore') as file:
        lines = file.readlines()

    i = 0
    while i < len(lines):
        line = lines[i].strip()

        # Look for [_line] entries
        if line == '[_line]':
            start_line_number = i + 1  # Line numbers are 1-indexed

            # Find the corresponding [end]
            entry_lines = []
            j = i + 1
            while j < len(lines):
                entry_lines.append(lines[j].rstrip())
                if lines[j].strip() == '[end]':
                    break
                j += 1

            if j < len(lines):  # Found [end]
                entry = '\n'.join(entry_lines[:-1])  # Exclude the [end] line

                # Extract Type
                type_match = re.search(r'Type=([^\s]+)', entry)
                line_type = type_match.group(1) if type_match else "N/A"

                # Extract String1 (name)
                string1_match = re.search(r'String1=0x04,([^\n]+)', entry)
                string1_name = string1_match.group(1) if string1_match else "N/A"

                # Get the full entry (add back the [_line] and [end] markers)
                full_entry = f"[_line]\n{entry}\n[end]"

                lines_data.append({
                    'Type': line_type,
                    'String1_Name': string1_name,
                    'Matching_Filters': '',  # Will be filled later
                    '20011_Line_Number': start_line_number,
                    'Style_Line_Number': '',  # Will be filled later
                    'Full_Entry': full_entry
                })

                i = j + 1  # Continue after [end]
            else:
                i += 1
        else:
            i += 1

    return lines_data

def match_filters_to_types(lines_data, type_filters):
    """Match the filters from style file to the type codes in 20011.txt."""
    expanded_data = []

    for entry in lines_data:
        line_type = entry['Type']
        if line_type in type_filters:
            # Create a separate row for each matching filter
            for filter_rule, style_line_number in type_filters[line_type]:
                new_entry = entry.copy()
                new_entry['Matching_Filters'] = filter_rule
                new_entry['Style_Line_Number'] = style_line_number
                expanded_data.append(new_entry)
        else:
            # No matching filters, keep the original entry
            entry['Matching_Filters'] = 'No matching filters found'
            entry['Style_Line_Number'] = ''
            expanded_data.append(entry)

    return expanded_data

def save_to_csv(data, output_filename):
    """Save the parsed data to a CSV file."""
    with open(output_filename, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['Type', 'String1_Name', 'Matching_Filters', '20011_Line_Number', 'Style_Line_Number', 'Full_Entry']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

        writer.writeheader()
        for row in data:
            writer.writerow(row)

def main():
    input_20011_file = 'typ-files/20011.txt'
    input_style_file = 'my-style/lines'
    output_file = '20011_lines_spreadsheet.csv'

    print(f"Parsing {input_20011_file}...")
    lines_data = parse_20011_lines(input_20011_file)

    print(f"Parsing {input_style_file}...")
    type_filters = parse_style_lines(input_style_file)

    print(f"Found {len(lines_data)} [_line] entries")
    print(f"Found {len(type_filters)} type codes with filters")

    print("Matching filters to types...")
    lines_data = match_filters_to_types(lines_data, type_filters)

    print(f"Saving to {output_file}...")
    save_to_csv(lines_data, output_file)

    print("Done! CSV file created successfully.")
    print(f"Total entries: {len(lines_data)}")

    # Show some statistics
    matched_count = sum(1 for entry in lines_data if entry['Matching_Filters'] != 'No matching filters found')
    print(f"Entries with matching filters: {matched_count}")
    print(f"Entries without matching filters: {len(lines_data) - matched_count}")

if __name__ == "__main__":
    main()
