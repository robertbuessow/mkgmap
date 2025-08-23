#!/usr/bin/env python3
"""
Script to apply changes from edited CSV file back to my-style/lines file.
Reads the edited CSV and updates the corresponding lines in the style file.
"""

import csv
import re
import shutil
from datetime import datetime

def read_csv_changes(original_csv_filename, edited_csv_filename):
    """Read both CSV files and extract changes by comparing them."""
    changes = {}
    new_rules = []

    # Read original CSV
    original_data = {}
    with open(original_csv_filename, 'r', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            key = (row['Type'], row['String1_Name'], row['20011_Line_Number'])
            original_data[key] = row['Matching_Filters']

    # Read edited CSV and compare
    with open(edited_csv_filename, 'r', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            key = (row['Type'], row['String1_Name'], row['20011_Line_Number'])
            original_filter = original_data.get(key, 'No matching filters found')
            edited_filter = row['Matching_Filters']

            # Check if this is a new rule (had no filters before, now has filters)
            if original_filter == 'No matching filters found' and edited_filter != 'No matching filters found':
                if row['Style_Line_Number']:
                    # This is an existing rule that was modified
                    line_number = int(row['Style_Line_Number'])
                    changes[line_number] = {
                        'type': row['Type'],
                        'name': row['String1_Name'],
                        'original_filter': original_filter,
                        'new_filter': edited_filter,
                        'line_number': line_number
                    }
                else:
                    # This is a completely new rule
                    new_rules.append({
                        'type': row['Type'],
                        'name': row['String1_Name'],
                        'new_filter': edited_filter
                    })

            # Check if this is a modified existing rule
            elif (original_filter != 'No matching filters found' and
                  edited_filter != 'No matching filters found' and
                  original_filter != edited_filter and
                  row['Style_Line_Number']):
                line_number = int(row['Style_Line_Number'])
                changes[line_number] = {
                    'type': row['Type'],
                    'name': row['String1_Name'],
                    'original_filter': original_filter,
                    'new_filter': edited_filter,
                    'line_number': line_number
                }

    return changes, new_rules

def backup_original_file(filename):
    """Create a backup of the original file."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"{filename}.backup_{timestamp}"
    shutil.copy2(filename, backup_filename)
    print(f"Created backup: {backup_filename}")
    return backup_filename

def apply_changes_to_lines_file(lines_filename, changes, new_rules):
    """Apply the changes to the my-style/lines file."""
    # Read the original file
    with open(lines_filename, 'r', encoding='utf-8') as file:
        lines = file.readlines()

    # Create a backup
    backup_filename = backup_original_file(lines_filename)

    # Track which lines have been modified
    modified_lines = set()

    # Process each change
    for line_number, change_info in changes.items():
        if line_number <= len(lines):
            print(f"Processing line {line_number}: {change_info['type']} - {change_info['name']}")
            print(f"  Original filter: {change_info['original_filter']}")
            print(f"  New filter: {change_info['new_filter']}")

            # Find the multi-line rule starting at this line
            rule_start = line_number - 1  # Convert to 0-based index
            rule_end = rule_start

            # Find the end of the rule (look for closing bracket)
            while rule_end < len(lines):
                line_content = lines[rule_end].strip()
                if line_content.endswith('}') or line_content.endswith(']'):
                    break
                rule_end += 1

            if rule_end < len(lines):
                # Extract the current rule
                current_rule_lines = lines[rule_start:rule_end + 1]
                current_rule = ' '.join([line.strip() for line in current_rule_lines])

                # Try to find the filter in the current rule
                # First try exact match, then try partial match
                filter_found = False
                if change_info['original_filter'] in current_rule:
                    filter_found = True
                    old_filter = change_info['original_filter']
                else:
                    # Try to find a similar filter by looking for the type code
                    type_code = change_info['type']
                    if f"[{type_code}" in current_rule:
                        # Extract the filter part before the type code
                        type_pos = current_rule.find(f"[{type_code}")
                        if type_pos > 0:
                            # Find the start of the filter (before any { or [)
                            filter_start = 0
                            for i in range(type_pos - 1, -1, -1):
                                if current_rule[i] in '{[':
                                    filter_start = i + 1
                                    break

                            old_filter = current_rule[filter_start:type_pos].strip()
                            filter_found = True
                            print(f"  Found filter by type code: {old_filter}")

                if filter_found:
                    print(f"  Found matching rule at lines {rule_start + 1}-{rule_end + 1}")

                    # Replace the filter in the rule
                    new_rule = current_rule.replace(old_filter, change_info['new_filter'])

                    # Split the new rule back into lines, preserving formatting
                    new_rule_parts = new_rule.split(' ')
                    current_line_idx = 0
                    new_lines = []

                    # Reconstruct the lines with proper formatting
                    current_line_content = ""
                    for part in new_rule_parts:
                        if part.endswith('}') or part.endswith(']'):
                            current_line_content += part
                            new_lines.append(current_line_content + '\n')
                            current_line_content = ""
                            current_line_idx += 1
                        elif part:
                            current_line_content += part + " "

                    # Update the lines in the file
                    for i, new_line in enumerate(new_lines):
                        if rule_start + i < len(lines):
                            lines[rule_start + i] = new_line

                    # Mark these lines as modified
                    for i in range(rule_start, rule_end + 1):
                        modified_lines.add(i)

                    print(f"  Updated lines {rule_start + 1}-{rule_end + 1}")
                else:
                    print(f"  Warning: Could not find filter in rule at line {line_number}")
                    print(f"  Current rule: {current_rule[:100]}...")
            else:
                print(f"  Warning: Could not find end of rule starting at line {line_number}")
        else:
            print(f"  Warning: Line number {line_number} exceeds file length ({len(lines)})")

    # Write the modified lines back to the file
    if modified_lines:
        with open(lines_filename, 'w', encoding='utf-8') as file:
            file.writelines(lines)
        print(f"\nApplied {len(modified_lines)} line modifications to {lines_filename}")

    # Process new rules to add
    print(f"\nNew rules to add:")
    for rule in new_rules:
        print(f"  {rule['type']} - {rule['name']}: {rule['new_filter']}")

    # Add new rules to the end of the file
    if new_rules:
        print(f"\nAdding new rules to the end of the file...")
        with open(lines_filename, 'a', encoding='utf-8') as file:
            file.write("\n# New rules added from CSV edits\n")
            for rule in new_rules:
                # Create a new rule line with the filter and type code
                new_rule_line = f"{rule['new_filter']} [{rule['type']} road_class=0 road_speed=1 resolution 22]\n"
                file.write(new_rule_line)
                print(f"  Added: {new_rule_line.strip()}")

    print(f"\nSummary:")
    print(f"  Total changes to apply: {len(changes)}")
    print(f"  New rules to add: {len(new_rules)}")
    print(f"  Lines modified: {len(modified_lines)}")
    print(f"  Backup created: {backup_filename}")

    return modified_lines, new_rules

def main():
    original_csv_filename = '20011_lines_spreadsheet.csv'
    edited_csv_filename = '20011_lines_spreadsheet_edited.csv'
    lines_filename = 'my-style/lines'

    print(f"Reading changes from {edited_csv_filename}...")
    changes, new_rules = read_csv_changes(original_csv_filename, edited_csv_filename)

    print(f"Found {len(changes)} changes to apply")
    print(f"Found {len(new_rules)} new rules to add")

    if not changes and not new_rules:
        print("No changes found. Exiting.")
        return

    if changes:
        print(f"\nChanges to apply:")
        for line_num, change in changes.items():
            print(f"  Line {line_num}: {change['type']} - {change['name']}")
            print(f"    {change['original_filter']} -> {change['new_filter']}")

    if new_rules:
        print(f"\nNew rules to add:")
        for rule in new_rules:
            print(f"  {rule['type']} - {rule['name']}: {rule['new_filter']}")

    print(f"\nApplying changes to {lines_filename}...")
    modified_lines, new_rules = apply_changes_to_lines_file(lines_filename, changes, new_rules)

    print(f"\nDone!")

if __name__ == "__main__":
    main()
