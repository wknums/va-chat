import csv
import os
import argparse
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents import SearchClient
from azure.search.documents.indexes.models import SimpleField

# Load environment variables from .env at repo root
load_dotenv()

# Parse command line arguments
parser = argparse.ArgumentParser(description="Update Azure AI Search index with original source URLs")
parser.add_argument("--dry-run", action="store_true", help="Show what would be updated without making changes")
args = parser.parse_args()

# Inputs from environment
# CSV with columns: filename, originalSourceURL
csv_file = os.getenv("SOURCEURL_MAPPING_CSV", "mapping.csv")

# Search resource and index

# Derive the search service name from the connection name if needed,
# or set AZURE_AI_SEARCH_SERVICE_NAME explicitly in .env to avoid guessing.
search_service_name = os.getenv("AZURE_AI_SEARCH_SERVICE_NAME")
if not search_service_name:
    # Fallback: take the first token before the first non-alphanumeric, as a heuristic
    # e.g. "devmmraisearchnlomaca4a7awm" is already a service name, so this just uses it
    raise ValueError("Error: AZURE_AI_SEARCH_SERVICE_NAME not set in .env")
    

# Knowledge source / index
# For a Foundry IQ knowledge source named "wcg-public-knowledgesource-1",
# the index is usually "<name>-index".
#index_name = os.getenv(
#    "AZURE_AI_SEARCH_INDEX_NAME"
#   ,
#)
index_name = os.getenv("AZURE_AI_SEARCH_INDEX_NAME")
if not index_name:
    raise ValueError("Either AZURE_AI_SEARCH_INDEX_NAME or KNOWLEDGE_SOURCE_NAME must be set in .env")

# Auth
endpoint = f"https://{search_service_name}.search.windows.net"
credential = DefaultAzureCredential()

# Clients
index_client = SearchIndexClient(endpoint, credential)
search_client = SearchClient(endpoint, index_name, credential)


def ensure_field_in_index(index_client: SearchIndexClient, index_name: str, field_name: str, dry_run: bool = False) -> None:
    index = index_client.get_index(index_name)
    field_names = [f.name for f in index.fields]
    if field_name not in field_names:
        if dry_run:
            print(f"DRY RUN: Would add field '{field_name}' to index '{index_name}'")
        else:
            index.fields.append(
                SimpleField(
                    name=field_name,
                    type="Edm.String",
                    filterable=True,
                    sortable=False,
                    facetable=False,
                    searchable=True,
                    retrievable=True,
                    stored=True,
                )
            )
            index_client.create_or_update_index(index)
            print(f"Added field '{field_name}' to index '{index_name}'")
    else:
        print(f"Field '{field_name}' already exists on index '{index_name}'")


def read_csv_mapping(csv_file_path: str) -> dict[str, str]:
    """Read mapping of filename -> originalSourceURL from CSV.

    The CSV is expected to have columns: filename, originalSourceURL
    where "filename" is the blob path segment, e.g.
    "wcg-public/re_registration-in-terms-of-...docx".
    """
    mapping: dict[str, str] = {}
    try:
        with open(csv_file_path, newline="", encoding="utf-8") as f:
            reader = csv.reader(f)  # Use regular reader instead of DictReader
            
            row_count = 0
            for row in reader:
                row_count += 1
                
                if len(row) < 2:
                    print(f"Skipping row {row_count}: insufficient columns ({len(row)})")
                    continue
                
                # First column is filename, second is URL
                filename = row[0].strip().lstrip('\ufeff') if row[0] else ""  # Remove BOM
                url = row[1].strip() if row[1] else ""
                
                if row_count <= 3:  # Debug first 3 rows
                    print(f"Row {row_count}: filename='{filename}', url='{url}'")
                
                if filename and url:
                    mapping[filename] = url
                    if row_count <= 3:
                        print(f"  Added mapping: '{filename}' -> '{url}'")
                else:
                    if row_count <= 3:
                        print(f"  Skipping row {row_count}: empty filename or URL")
                        
            print(f"Processed {row_count} rows from CSV")
                    
    except Exception as e:
        print(f"Error reading CSV file: {e}")
        return mapping
    print(f"Loaded {len(mapping)} mappings from {csv_file_path}")
    
    # Debug output: show the CSV mappings
    if mapping:
        print("\nCSV mappings loaded:")
        for i, (filename, url) in enumerate(mapping.items()):
            if i < 5:  # Show first 5 mappings
                print(f"  '{filename}' -> '{url}'")
            elif i == 5:
                print(f"  ... and {len(mapping) - 5} more")
                break
    else:
        print("WARNING: No mappings found in CSV file!")
    
    return mapping


def update_documents(search_client: SearchClient, mapping: dict[str, str], field_name: str, dry_run: bool = False) -> None:
    """Update documents by matching mapping filenames to the tail of blob_url.

    The knowledge source index contains a field (typically "blob_url") that
    stores the full blob URL, for example:

        https://<account>.blob.core.windows.net/wcg-public/dir/file.docx

    The CSV, however, only contains the container-relative path, e.g.:

        wcg-public/dir/file.docx

    Since blob_url is not searchable in the knowledge source index, we retrieve
    all documents and filter by blob_url suffix match in memory.
    
    Args:
        search_client: Azure Search client
        mapping: Dictionary of filename -> originalSourceURL
        field_name: Name of the field to add/update
        dry_run: If True, only print what would be updated without making changes
    """

    # Allow overriding the blob URL field name via env, default to "blob_url"
    blob_url_field = os.getenv("KNOWLEDGE_SOURCE_BLOB_URL_FIELD", "blob_url")

    print(f"Retrieving all documents to match against blob_url field '{blob_url_field}'...")
    
    # Since blob_url is not searchable, we need to retrieve all documents
    # and filter by blob_url suffix match in memory
    all_results = list(
        search_client.search(
            search_text="*",
            select=["uid", blob_url_field],
            include_total_count=True,
        )
    )

    print(f"Retrieved {len(all_results)} documents from index")

    # Debug output: show some blob URLs from the index
    if all_results:
        print("\nSample blob URLs from index:")
        for i, doc in enumerate(all_results):
            if i < 5:  # Show first 5 blob URLs
                blob_url_value = doc.get(blob_url_field, "") or ""
                uid = doc.get("uid")
                print(f"  UID: {uid} -> '{blob_url_value}'")
            elif i == 5:
                print(f"  ... and {len(all_results) - 5} more")
                break

    # Build a mapping from filename suffix to document UIDs
    filename_to_docs = {}
    for doc in all_results:
        blob_url_value = doc.get(blob_url_field, "") or ""
        uid = doc.get("uid")
        if not uid:
            continue
            
        # Check which filenames from our mapping this blob_url matches
        for filename in mapping.keys():
            if blob_url_value.endswith(filename):
                if filename not in filename_to_docs:
                    filename_to_docs[filename] = []
                filename_to_docs[filename].append((uid, blob_url_value))

    # Debug output: show matching results
    if not filename_to_docs and mapping:
        print(f"\nDEBUG: No matches found between CSV filenames and blob URLs")
        print("Checking for partial matches or common patterns...")
        
        # Show some examples of how filenames compare to blob URLs
        sample_filename = next(iter(mapping.keys())) if mapping else None
        if sample_filename:
            print(f"\nExample CSV filename: '{sample_filename}'")
            matches_found = []
            for doc in all_results[:10]:  # Check first 10 docs
                blob_url = doc.get(blob_url_field, "")
                if sample_filename in blob_url:
                    matches_found.append(blob_url)
            
            if matches_found:
                print("Blob URLs containing parts of the filename:")
                for url in matches_found[:3]:
                    print(f"  '{url}'")
            else:
                print("No blob URLs contain any part of the sample filename")

    total_would_update = 0
    
    if dry_run:
        print(f"\n{'='*80}")
        print("DRY RUN MODE - No changes will be made to the index")
        print(f"{'='*80}")

    for filename, url in mapping.items():
        if filename not in filename_to_docs:
            print(f"No index documents found with blob_url ending in '{filename}'")
            continue

        matching_docs = filename_to_docs[filename]
        print(f"\nFound {len(matching_docs)} document(s) for filename '{filename}':")
        
        if dry_run:
            print(f"  Would add field '{field_name}' = '{url}'")
            for uid, blob_url_value in matching_docs:
                print(f"    - Document UID: {uid}")
                print(f"      Blob URL: {blob_url_value}")
            total_would_update += len(matching_docs)
        else:
            batch = []
            for uid, _ in matching_docs:
                batch.append(
                    {
                        "@search.action": "merge",
                        "uid": uid,
                        field_name: url,
                    }
                )

            if batch:
                result = search_client.upload_documents(documents=batch)
                updated_for_file = len([r for r in result if r.succeeded])
                total_would_update += updated_for_file
                print(
                    f"Updated {updated_for_file} document(s) for filename '{filename}' with {field_name}."
                )

    if dry_run:
        print(f"\n{'='*80}")
        print(f"DRY RUN SUMMARY: Would update {total_would_update} documents total")
        print("To perform actual updates, run without --dry-run flag")
        print(f"{'='*80}")
    else:
        print(f"Total documents updated: {total_would_update}")


if __name__ == "__main__":
    field_name = os.getenv("ORIGINAL_SOURCE_URL_FIELD_NAME", "originalSourceURL")
    print(f"Search service: {search_service_name}")
    print(f"Index name:     {index_name}")
    print(f"CSV file:       {csv_file}")
    print(f"Field name:     {field_name}")
    print(f"Dry run mode:   {args.dry_run}")

    ensure_field_in_index(index_client, index_name, field_name, args.dry_run)
    mapping = read_csv_mapping(csv_file)
    update_documents(search_client, mapping, field_name, args.dry_run)