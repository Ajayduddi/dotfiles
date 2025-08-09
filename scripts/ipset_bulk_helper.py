#!/usr/bin/env python3
"""
Ultra-fast bulk ipset operations helper
Optimized for handling large IP datasets (100K+ IPs)
"""

import sys
import subprocess
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

class ProgressBar:
    def __init__(self, total, prefix="Progress", width=50, progress_file=None):
        self.total = total
        self.prefix = prefix
        self.width = width
        self.current = 0
        self.lock = threading.Lock()
        # Disable all progress output for speed
        self.use_universal_progress = False
    
    def update(self, increment=1):
        with self.lock:
            self.current += increment
            # No progress output for maximum speed
    
    def _update_universal_progress(self):
        """Disabled for speed"""
        pass
    
    def _display(self):
        # Disabled for speed
        pass
    
    def finish(self):
        # Disabled for speed
        pass

def run_command(cmd, timeout=30):
    """Run a command with timeout"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"
    except Exception as e:
        return False, "", str(e)

def bulk_add_ipset_native(ipset_name, ips_file):
    """Use native ipset restore for maximum speed"""
    print(f"🚀 Using native ipset restore for {ipset_name}")
    
    # Create restore file
    restore_file = f"/tmp/{ipset_name}_restore.txt"
    
    try:
        # Count total IPs first for progress tracking
        with open(ips_file, 'r') as infile:
            total_ips = sum(1 for line in infile if line.strip() and not line.startswith('#'))
        
        # Create restore file
        processed = 0
        with open(ips_file, 'r') as infile, open(restore_file, 'w') as outfile:
            for line in infile:
                ip = line.strip()
                if ip and not ip.startswith('#'):
                    outfile.write(f"add {ipset_name} {ip}\n")
                    processed += 1
        # Execute ipset restore with optimized settings
        cmd = f"sudo ipset restore -exist < {restore_file}"
        success, stdout, stderr = run_command(cmd, timeout=600)  # Increased timeout
        
        os.unlink(restore_file)
        return success
        
    except Exception as e:
        print(f"❌ Native ipset restore failed: {e}")
        if os.path.exists(restore_file):
            os.unlink(restore_file)
        return False

def process_batch_individually(batch_ips, ipset_name):
    """Optimized individual processing with parallel execution and progress feedback"""
    from concurrent.futures import ThreadPoolExecutor, as_completed
    import threading
    
    total_ips = len(batch_ips)
    added = 0
    processed = 0
    lock = threading.Lock()
    
    print(f"🔄 Processing {total_ips} IPs individually with parallel workers...")
    
    # Create progress bar for individual processing
    progress = ProgressBar(total_ips, "Individual processing")
    
    def process_single_ip(ip):
        nonlocal added, processed
        try:
            cmd = f"sudo firewall-cmd --ipset={ipset_name} --add-entry={ip}"
            success, stdout, stderr = run_command(cmd, timeout=5)  # Reduced timeout
            
            with lock:
                processed += 1
                if success:
                    added += 1
                elif "already in set" not in stderr.lower() and "overlaps" not in stderr.lower():
                    # Only count non-duplicate, non-overlap errors as failures
                    pass
                
                # Update progress every 10 IPs to avoid spam
                if processed % 10 == 0 or processed == total_ips:
                    progress.update(processed)
            
            return success
        except Exception:
            with lock:
                processed += 1
                if processed % 10 == 0 or processed == total_ips:
                    progress.update(processed)
            return False
    
    # Process IPs in parallel with limited workers to avoid overwhelming the system
    max_workers = min(8, len(batch_ips))  # Limit concurrent firewall operations
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all tasks
        future_to_ip = {executor.submit(process_single_ip, ip): ip for ip in batch_ips}
        
        # Wait for completion
        for future in as_completed(future_to_ip):
            try:
                future.result()  # This will raise any exceptions
            except Exception:
                pass  # Individual failures are already handled
    
    progress.finish()
    print(f"✅ Individual processing completed: {added}/{total_ips} IPs added successfully")
    
    return added

def bulk_add_firewalld_parallel(ipset_name, ips_file, batch_size=10000, max_workers=3):
    """Parallel batch processing for firewalld - optimized for performance"""
    print(f"🚀 Using native ipset restore for {ipset_name}")
    
    # Read all IPs efficiently
    with open(ips_file, 'r') as f:
        ips = [line.strip() for line in f if line.strip() and not line.startswith('#')]
    
    total_ips = len(ips)
    if total_ips == 0:
        return True
    
    # Create larger batches for better performance
    batches = [ips[i:i + batch_size] for i in range(0, len(ips), batch_size)]
    total_batches = len(batches)
    
    print(f"📦 Processing {total_ips} IPs in {total_batches} batches")
    
    progress = ProgressBar(total_batches, "Processing batches")
    successful_batches = 0
    total_added = 0
    
    def process_batch(batch_idx, batch_ips):
        # Use a more accessible temp directory
        import tempfile
        temp_dir = tempfile.gettempdir()
        batch_file = os.path.join(temp_dir, f"batch_{ipset_name}_{batch_idx}_{os.getpid()}.txt")
        
        try:
            # Write batch to file efficiently with proper permissions
            with open(batch_file, 'w') as f:
                f.write('\n'.join(batch_ips) + '\n')
            
            # Set proper permissions
            os.chmod(batch_file, 0o644)
            
            # Try firewall-cmd bulk add to runtime (immediate effect)
            cmd = f"sudo firewall-cmd --ipset={ipset_name} --add-entries-from-file={batch_file}"
            success, stdout, stderr = run_command(cmd, timeout=120)
            
            if success:
                added = len(batch_ips)
            else:
                # Check for overlap errors and handle gracefully
                if "overlaps" in stderr.lower():
                    print(f"⚠️ Batch {batch_idx} has CIDR overlaps - using optimized individual processing...")
                    added = process_batch_individually(batch_ips, ipset_name)
                    success = added > 0
                elif "already in set" in stderr.lower():
                    # Most IPs already exist, try individual processing to add new ones
                    print(f"⚠️ Batch {batch_idx} has duplicates - filtering and adding new entries...")
                    added = process_batch_individually(batch_ips, ipset_name)
                    success = added > 0
                else:
                    added = 0
                    print(f"⚠️ Batch {batch_idx} failed: {stderr[:100]}")
            
            # Clean up batch file
            try:
                os.unlink(batch_file)
            except (OSError, PermissionError):
                pass  # Ignore cleanup errors
                
            return success, added
            
        except Exception as e:
            try:
                if os.path.exists(batch_file):
                    os.unlink(batch_file)
            except (OSError, PermissionError):
                pass  # Ignore cleanup errors
            print(f"⚠️ Batch {batch_idx} exception: {str(e)[:100]}")
            return False, 0
    
    # Process batches in parallel
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_batch = {
            executor.submit(process_batch, idx, batch): idx 
            for idx, batch in enumerate(batches)
        }
        
        for future in as_completed(future_to_batch):
            success, added = future.result()
            if success:
                successful_batches += 1
            total_added += added
            progress.update()
    
    progress.finish()
    print(f"✅ Added {total_added}/{total_ips} IPs ({successful_batches}/{total_batches} batches successful)")
    
    return total_added > 0

def main():
    if len(sys.argv) != 4:
        print("Usage: python3 ipset_bulk_helper.py <operation> <ipset_name> <ips_file>")
        print("Operations: add")
        sys.exit(1)
    
    operation = sys.argv[1]
    ipset_name = sys.argv[2]
    ips_file = sys.argv[3]
    
    if not os.path.exists(ips_file):
        print(f"❌ File not found: {ips_file}")
        sys.exit(1)
    
    # Count total IPs
    with open(ips_file, 'r') as f:
        total_ips = sum(1 for line in f if line.strip() and not line.startswith('#'))
    
    start_time = time.time()
    
    if operation == "add":
        # Try native ipset first (fastest)
        if bulk_add_ipset_native(ipset_name, ips_file):
            success = True
        else:
            # Fallback to parallel firewalld processing
            success = bulk_add_firewalld_parallel(ipset_name, ips_file)
    else:
        print(f"❌ Unknown operation: {operation}")
        sys.exit(1)
    
    end_time = time.time()
    duration = end_time - start_time
    
    if success:
        print(f"🎉 Operation completed successfully in {duration:.2f} seconds")
        print(f"⚡ Speed: {total_ips/duration:.0f} IPs/second")
        sys.exit(0)
    else:
        print(f"❌ Operation failed after {duration:.2f} seconds")
        sys.exit(1)

if __name__ == "__main__":
    main()