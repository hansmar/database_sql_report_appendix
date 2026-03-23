"""
Banking System Console Application
Connects to Oracle DB and provides a text-based menu.

"""

import oracledb
import sys
from datetime import datetime

# ============================================
# Database Connection
# ============================================
DB_CONFIG = {
    "user": "banki",
    "password": "password",
    "dsn": "localhost:1521/XEPDB1"
}


def get_connection():
    """Create and return a database connection."""
    try:
        conn = oracledb.connect(**DB_CONFIG)
        return conn
    except oracledb.Error as e:
        print(f"\n  Feilur: Onki samband við databasan: {e}")
        sys.exit(1)


# ============================================
# Display Helpers
# ============================================
def print_header(title):
    """Print a formatted section header."""
    width = 60
    print("\n" + "=" * width)
    print(f"  {title}")
    print("=" * width)


def print_table(headers, rows):
    """Print data in a formatted table."""
    if not rows:
        print("\n  Eingin data funnin.\n")
        return

    col_widths = [len(h) for h in headers]
    for row in rows:
        for i, val in enumerate(row):
            col_widths[i] = max(col_widths[i], len(str(val)))

    header_line = "  "
    separator = "  "
    for i, h in enumerate(headers):
        header_line += f"{h:<{col_widths[i] + 2}}"
        separator += "-" * (col_widths[i] + 2)
    print(f"\n{header_line}")
    print(separator)

    for row in rows:
        line = "  "
        for i, val in enumerate(row):
            line += f"{str(val):<{col_widths[i] + 2}}"
        print(line)
    print()


def get_input(prompt, allow_empty=False):
    """Get user input with optional empty check."""
    val = input(prompt).strip()
    if not allow_empty and not val:
        return None
    return val


def get_number(prompt):
    """Get a numeric input from the user."""
    val = input(prompt).strip()
    try:
        return float(val)
    except ValueError:
        return None


def get_int(prompt):
    """Get an integer input from the user."""
    val = input(prompt).strip()
    if val.isdigit():
        return int(val)
    return None


# ============================================
# View Functions
# ============================================
def view_customers(conn):
    """List all customers with their personal info."""
    print_header("Kundar")
    cursor = conn.cursor()
    cursor.execute("""
        SELECT c.customer_id, p.first_name, p.last_name,
               p.town_name, c.customer_type
        FROM Customer c
        JOIN Person p ON c.person_id = p.person_id
        ORDER BY c.customer_id
    """)
    rows = cursor.fetchall()
    print_table(["ID", "Fornavn", "Eftirnavn", "Bygd", "Slag"], rows)
    cursor.close()


def view_accounts(conn):
    """List all accounts with owner names and balances."""
    print_header("Kontoir")
    cursor = conn.cursor()
    cursor.execute("""
        SELECT a.account_id, p.first_name || ' ' || p.last_name AS eigari,
               a.account_type, a.balance, a.status
        FROM Account a
        JOIN Owns o ON a.account_id = o.account_id
        JOIN Customer c ON o.customer_id = c.customer_id
        JOIN Person p ON c.person_id = p.person_id
        ORDER BY a.account_id
    """)
    rows = cursor.fetchall()
    print_table(["Konto", "Eigari", "Slag", "Saldo", "Status"], rows)
    cursor.close()


def view_family(conn):
    """Show family relationships."""
    print_header("Familju-samband")
    cursor = conn.cursor()
    cursor.execute("""
        SELECT g.first_name || ' ' || g.last_name AS persÛnur,
               ch.first_name || ' ' || ch.last_name AS relatera_til,
               f.relationship_type
        FROM Family f
        JOIN Person g ON f.guardian_person_id = g.person_id
        JOIN Person ch ON f.child_person_id = ch.person_id
        ORDER BY f.family_id
    """)
    rows = cursor.fetchall()
    print_table(["PersÛnur", "Relatera til", "Samband"], rows)
    cursor.close()


def view_pending(conn):
    """Show all pending (unbooked) kassakladda entries."""
    print_header("Kassakladda - ”bÛkaar transaktionir")
    cursor = conn.cursor()
    cursor.execute("""
        SELECT t.transaction_id, t.transaction_type, t.amount,
               t.from_account_id, t.to_account_id,
               t.date_time, t.description
        FROM Transaction_
        t WHERE t.status = 'Pending'
        ORDER BY t.date_time
    """)
    rows = cursor.fetchall()
    print_table(["TXN ID", "Slag", "UpphÊdd", "Fr·", "Til", "Dato/TÌ", "L˝sing"], rows)
    cursor.close()


def view_journal(conn):
    """Show all journal entries."""
    print_header("BÛkaar transaktionir (Journal Entries)")
    cursor = conn.cursor()
    cursor.execute("""
        SELECT j.journal_entry_id, j.reference, j.description,
               j.entry_date, j.status
        FROM JournalEntry j
        ORDER BY j.entry_date, j.journal_entry_id
    """)
    rows = cursor.fetchall()
    print_table(["ID", "Referansa", "L˝sing", "Dato", "Status"], rows)
    cursor.close()


def account_statement(conn):
    """Show account statement (kontoavrit) for a given account."""
    print_header("Kontoavrit")
    account_id = get_int("  Skriva konto ID: ")
    if account_id is None:
        print("  ”gyldugt konto ID.")
        return

    cursor = conn.cursor()

    # Get account info
    cursor.execute("""
        SELECT a.account_id, a.account_type, a.balance, a.status,
               p.first_name || ' ' || p.last_name AS eigari
        FROM Account a
        JOIN Owns o ON a.account_id = o.account_id
        JOIN Customer c ON o.customer_id = c.customer_id
        JOIN Person p ON c.person_id = p.person_id
        WHERE a.account_id = :aid
    """, {"aid": account_id})

    account = cursor.fetchone()
    if not account:
        print(f"  Konto {account_id} finnst ikki.")
        cursor.close()
        return

    print(f"\n  Konto:  {account[0]}  ({account[1]})")
    print(f"  Eigari: {account[4]}")
    print(f"  Status: {account[3]}")

    # Get all transactions (both pending and posted)
    cursor.execute("""
        SELECT t.date_time, t.transaction_type, t.description,
               t.from_account_id, t.to_account_id, t.amount, t.status
        FROM Transaction_ t
        WHERE t.account_id = :aid
   		OR t.from_account_id = :aid
   		OR t.to_account_id = :aid
        ORDER BY t.date_time
    """, {"aid": account_id})

    rows = cursor.fetchall()
    print_table(
        ["Dato/TÌ", "Slag", "L˝sing", "Fr·", "Til", "UpphÊdd", "Status"],
        rows
    )
    print(f"  N˙verandi saldo: {account[2]:,.2f} kr\n")
    cursor.close()


# ============================================
# Kassakladda Journal Entry Functions (insert as Pending)
# ============================================
def next_txn_id(cursor):
    """Get the next available transaction ID."""
    cursor.execute("SELECT seq_transaction.NEXTVAL FROM DUAL")
    return cursor.fetchone()[0]


def account_exists(cursor, account_id):
    """Check if an account exists and return True/False."""
    cursor.execute("SELECT 1 FROM Account WHERE account_id = :aid", {"aid": account_id})
    return cursor.fetchone() is not None


def deposit(conn):
    """Enter a deposit into the kassakladda (Pending)."""
    print_header("Kassakladda - Innlegg (Deposit)")
    account_id = get_int("  Konto ID: ")
    if account_id is None:
        print("  ”gyldugt konto ID.")
        return

    amount = get_number("  UpphÊdd: ")
    if amount is None or amount <= 0:
        print("  UpphÊdd m· vera st¯rri enn 0.")
        return

    description = get_input("  L˝sing: ", allow_empty=True) or "Innlegg"

    cursor = conn.cursor()
    try:
        if not account_exists(cursor, account_id):
            print(f"  Konto {account_id} finnst ikki.")
            return

        txn_id = next_txn_id(cursor)

        cursor.execute("""
            INSERT INTO Transaction_ (transaction_id, account_id, from_account_id,
                to_account_id, transaction_type, amount, date_time, description, status)
            VALUES (:tid, :aid, NULL, :aid, 'Deposit', :amt,
                SYSTIMESTAMP, :descr, 'Pending')
        """, {"tid": txn_id, "aid": account_id, "amt": amount, "descr": description})

        conn.commit()
        print(f"\n  Innlegg av {amount:,.2f} kr skr·sett · kassakladdu. (TXN-{txn_id})")
        print(f"  Status: Pending - bÛka fyri at gera galdandi.")
    except oracledb.Error as e:
        conn.rollback()
        print(f"\n  Feilur: {e}")
    finally:
        cursor.close()


def withdrawal(conn):
    """Enter a withdrawal into the kassakladda (Pending)."""
    print_header("Kassakladda - ⁄tt¯ka (Withdrawal)")
    account_id = get_int("  Konto ID: ")
    if account_id is None:
        print("  ”gyldugt konto ID.")
        return

    amount = get_number("  UpphÊdd: ")
    if amount is None or amount <= 0:
        print("  UpphÊdd m· vera st¯rri enn 0.")
        return

    description = get_input("  L˝sing: ", allow_empty=True) or "⁄tt¯ka"

    cursor = conn.cursor()
    try:
        if not account_exists(cursor, account_id):
            print(f"  Konto {account_id} finnst ikki.")
            return

        txn_id = next_txn_id(cursor)

        cursor.execute("""
            INSERT INTO Transaction_ (transaction_id, account_id, from_account_id,
                to_account_id, transaction_type, amount, date_time, description, status)
            VALUES (:tid, :aid, :aid, NULL, 'Withdrawal', :amt,
                SYSTIMESTAMP, :descr, 'Pending')
        """, {"tid": txn_id, "aid": account_id, "amt": amount, "descr": description})

        conn.commit()
        print(f"\n  ⁄tt¯ka av {amount:,.2f} kr skr·sett · kassakladdu. (TXN-{txn_id})")
        print(f"  Status: Pending - bÛka fyri at gera galdandi.")
    except oracledb.Error as e:
        conn.rollback()
        print(f"\n  Feilur: {e}")
    finally:
        cursor.close()


def transfer(conn):
    """Enter a transfer into the kassakladda (Pending)."""
    print_header("Kassakladda - Flyting (Transfer)")
    from_id = get_int("  Fr· konto ID: ")
    if from_id is None:
        print("  ”gyldugt konto ID.")
        return

    to_id = get_int("  Til konto ID: ")
    if to_id is None:
        print("  ”gyldugt konto ID.")
        return

    if from_id == to_id:
        print("  Fr· og til konto kunnu ikki vera ta sama.")
        return

    amount = get_number("  UpphÊdd: ")
    if amount is None or amount <= 0:
        print("  UpphÊdd m· vera st¯rri enn 0.")
        return

    description = get_input("  L˝sing: ", allow_empty=True) or "Flyting"

    cursor = conn.cursor()
    try:
        if not account_exists(cursor, from_id):
            print(f"  Konto {from_id} finnst ikki.")
            return
        if not account_exists(cursor, to_id):
            print(f"  Konto {to_id} finnst ikki.")
            return

        txn_id = next_txn_id(cursor)

        cursor.execute("""
            INSERT INTO Transaction_ (transaction_id, account_id, from_account_id,
                to_account_id, transaction_type, amount, date_time, description, status)
            VALUES (:tid, :fid, :fid, :tid2, 'Transfer', :amt,
                SYSTIMESTAMP, :descr, 'Pending')
        """, {"tid": txn_id, "fid": from_id, "tid2": to_id, "amt": amount, "descr": description})

        conn.commit()
        print(f"\n  Flyting av {amount:,.2f} kr fr· {from_id} til {to_id} skr·sett · kassakladdu. (TXN-{txn_id})")
        print(f"  Status: Pending - bÛka fyri at gera galdandi.")
    except oracledb.Error as e:
        conn.rollback()
        print(f"\n  Feilur: {e}")
    finally:
        cursor.close()


# ============================================
# Booking Functions (calls stored procedures)
# ============================================
def book_single(conn):
    """Book a single pending transaction via stored procedure."""
    print_header("BÛka eina transaktiÛn")

    # Show pending first
    view_pending(conn)

    txn_id = get_int("  Transaction ID at bÛka: ")
    if txn_id is None:
        print("  ”gyldugt transaction ID.")
        return

    cursor = conn.cursor()
    try:
        cursor.callproc("book_transaction", [txn_id])
        conn.commit()
        print(f"\n  Transaction {txn_id} er bÛka!")
    except oracledb.Error as e:
        conn.rollback()
        print(f"\n  Feilur: {e}")
    finally:
        cursor.close()


def book_all(conn):
    """Book all pending transactions via stored procedure."""
    print_header("BÛka allar ÛbÛkaar transaktionir")

    cursor = conn.cursor()
    try:
        # Count pending
        cursor.execute("SELECT COUNT(*) FROM Transaction_ WHERE status = 'Pending'")
        count = cursor.fetchone()[0]

        if count == 0:
            print("\n  Eingin ÛbÛka transaktiÛn at bÛka.")
            cursor.close()
            return

        print(f"\n  {count} ÛbÛkaar transaktionir funnir.")
        confirm = input("  BÛka allar? (j/n): ").strip().lower()

        if confirm == 'j':
            cursor.callproc("book_all_pending")
            conn.commit()
            print(f"\n  Allar {count} transaktionir eru bÛkaar!")
        else:
            print("\n  Avl˝st.")
    except oracledb.Error as e:
        conn.rollback()
        print(f"\n  Feilur: {e}")
    finally:
        cursor.close()

def run_interest(conn):
    """Run monthly interest calculation via stored procedure."""
    print_header("Renturokning")
    date_str = get_input("  Dato (YYYY-MM-DD), t.d. 2026-03-31: ")
    if date_str is None:
        print("  Ógyldugt dato.")
        return

    cursor = conn.cursor()
    try:
        calc_date = datetime.strptime(date_str, "%Y-%m-%d")
        cursor.callproc("calculate_interest", [calc_date])
        conn.commit()
        print(f"\n  Renturokning koyrd fyri {date_str}!")
    except ValueError:
        print("  Ógyldugt dato format. Brúka YYYY-MM-DD.")
    except oracledb.Error as e:
        conn.rollback()
        print(f"\n  Feilur: {e}")
    finally:
        cursor.close()


# ============================================
# Family Account Access
# ============================================
def family_account_view(conn):
    """View accounts of family members (spouse/children)."""
    print_header("Familju-kontoir")
    person_id = get_int("  TÌtt person ID: ")
    if person_id is None:
        print("  ”gyldugt person ID.")
        return

    cursor = conn.cursor()

    # Find family members this person can see
    cursor.execute("""
        SELECT f.child_person_id AS related_id,
               p.first_name || ' ' || p.last_name AS navn,
               f.relationship_type
        FROM Family f
        JOIN Person p ON f.child_person_id = p.person_id
        WHERE f.guardian_person_id = :pid
    """, {"pid": person_id})

    family = cursor.fetchall()
    if not family:
        print("  Eingi familju-samband funnin.")
        cursor.close()
        return

    print_table(["Person ID", "Navn", "Samband"], family)

    # Show accounts for each family member
    for member in family:
        related_id = member[0]
        name = member[1]
        relation = member[2]

        cursor.execute("""
            SELECT a.account_id, a.account_type, a.balance, a.status
            FROM Account a
            JOIN Owns o ON a.account_id = o.account_id
            JOIN Customer c ON o.customer_id = c.customer_id
            WHERE c.person_id = :pid
        """, {"pid": related_id})

        accounts = cursor.fetchall()
        if accounts:
            print(f"  --- {name} ({relation}) ---")
            print_table(["Konto", "Slag", "Saldo", "Status"], accounts)

    cursor.close()


# ============================================
# Main Menu
# ============================================
def main_menu():
    """Display the main menu and handle user input."""
    conn = get_connection()
    print_header("Bankaskipan")
    print("  Samband vi databasan!\n")

    while True:
        print("=" * 60)
        print("  HÿVU–SMENU")
        print("=" * 60)
        print()
        print("  -- Yvirlit --")
        print("  1. VÌs kundar")
        print("  2. VÌs kontoir")
        print("  3. VÌs familju samband")
        print("  4. Kontoavrit (account statement)")
        print("  5. Familju kontoir (spouse/child access)")
        print()
        print("  -- Kassakladda (tasta inn) --")
        print("  6. Innlegg (Deposit)")
        print("  7. ⁄tt¯ka (Withdrawal)")
        print("  8. Flyting (Transfer)")
        print("  9. VÌs ÛbÛkaar transaktionir")
        print()
        print("  -- BÛking --")
        print("  10. BÛka eina transaktiÛn")
        print("  11. BÛka allar ÛbÛkaar")
        print("  12. VÌs journal entries")
        print("  13. Renturokning (interest calculation)")
        print()
        print("  0.  Enda")
        print("-" * 60)

        choice = get_input("  Vel: ")

        if choice == "1":
            view_customers(conn)
        elif choice == "2":
            view_accounts(conn)
        elif choice == "3":
            view_family(conn)
        elif choice == "4":
            account_statement(conn)
        elif choice == "5":
            family_account_view(conn)
        elif choice == "6":
            deposit(conn)
        elif choice == "7":
            withdrawal(conn)
        elif choice == "8":
            transfer(conn)
        elif choice == "9":
            view_pending(conn)
        elif choice == "10":
            book_single(conn)
        elif choice == "11":
            book_all(conn)
        elif choice == "12":
            view_journal(conn)
        elif choice == "13":
            run_interest(conn)
        elif choice == "0":
            print("\n  FarvÊl!\n")
            conn.close()
            break
        else:
            print("\n  ”gyldugt val. Royn aftur.\n")


if __name__ == "__main__":
    main_menu()
