/*
 * CLCL
 *
 * tool_template.c
 *
 * Copyright (C) 1996-2003 by Nakashima Tomoaki. All rights reserved.
 *		http://www.nakka.com/
 *		nakka@nakka.com
 */

/* Include Files */
#define _INC_OLE
#include <windows.h>
#undef  _INC_OLE
#include <commctrl.h>

#include "..\CLCLPlugin.h"

#include "resource.h"

/* Define */
#define ID_TREE							100
#define ID_CONTAINER					101

/* Global Variables */
HINSTANCE hInst;
static TCHAR find_str[BUF_SIZE];
static int op_ignore_case = 1;

/* Local Function Prototypes */
static BOOL find_text(const HWND hWnd, const TCHAR *str, const int icase, const BOOL pos_start);
static int find_item(const HWND hWnd, const HTREEITEM hitem, const HTREEITEM end_item, const TCHAR *str, const int icase);
static void find_tree(const HWND hWnd, const TCHAR *str, const int icase);

/*
 * DllMain - メイン
 */
int WINAPI DllMain(HINSTANCE hInstance, DWORD fdwReason, PVOID pvReserved)
{
	switch (fdwReason) {
	case DLL_PROCESS_ATTACH:
		hInst = hInstance;
		break;

	case DLL_PROCESS_DETACH:
	case DLL_THREAD_ATTACH:
	case DLL_THREAD_DETACH:
		break;
	}
	return TRUE;
}

/*
 * get_tool_info - ツール情報取得
 */
__declspec(dllexport) BOOL CALLBACK get_tool_info(const HWND hWnd, const int index, TOOL_GET_INFO *tgi)
{
	switch (index) {
	case 0:
		lstrcpy(tgi->title, TEXT("検索(&F)..."));
		lstrcpy(tgi->func_name, TEXT("tool_find"));
		lstrcpy(tgi->cmd_line, TEXT(""));
		tgi->call_type =  CALLTYPE_MENU | CALLTYPE_VIEWER;	// CALLTYPE_
		return TRUE;

	case 1:
		lstrcpy(tgi->title, TEXT("次を検索(&N)"));
		lstrcpy(tgi->func_name, TEXT("tool_find_next"));
		lstrcpy(tgi->cmd_line, TEXT(""));
		tgi->call_type =  CALLTYPE_MENU | CALLTYPE_VIEWER;	// CALLTYPE_
		return TRUE;

	case 2:
		return FALSE;
	}
	return FALSE;
}

/*
 * find_text - テキストから検索
 */
static BOOL find_text(const HWND hWnd, const TCHAR *str, const int icase, const BOOL pos_start)
{
	HWND wkWnd;
	TCHAR *buf;
	TCHAR *p;
	DWORD size;
	DWORD st = 0, en = 0;
	int find_str_len = lstrlen(str);
	int str_len;
	BOOL ret;

	// バージョンチェック
	if (SendMessage(hWnd, WM_GET_VERSION, 0, 0) < 108) {
		return FALSE;
	}

	// ウィンドウ検索
	if (IsWindowVisible(GetDlgItem(hWnd, ID_CONTAINER)) == 0) {
		return FALSE;
	}
	wkWnd = GetWindow(GetDlgItem(hWnd, ID_CONTAINER), GW_CHILD);
	while (wkWnd != NULL && IsWindowVisible(wkWnd) == 0) {
		wkWnd = GetWindow(wkWnd, GW_HWNDNEXT);
	}
	if (wkWnd == NULL) {
		return FALSE;
	}

	// テキスト取得
	if ((size = SendMessage(wkWnd, WM_GETTEXTLENGTH, 0, 0)) <= 0) {
		return FALSE;
	}
	if ((buf = LocalAlloc(LMEM_FIXED, sizeof(TCHAR) * (size + 1))) == NULL) {
		return FALSE;
	}
	if (SendMessage(wkWnd, WM_GETTEXT, size + 1, (LPARAM)buf) <= 0) {
		LocalFree(buf);
		return FALSE;
	}
	if (pos_start == FALSE) {
		SendMessage(wkWnd, EM_GETSEL, (WPARAM)&st, (LPARAM)&en);
	}

	// テキスト検索
	p = buf + ((st < en) ? en : st);
	str_len = lstrlen(p);
	ret = FALSE;
	for (; *p != TEXT('\0') && find_str_len <= str_len; p++, str_len--) {
		if (CompareString(MAKELCID(MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), SORT_DEFAULT),
			(icase == 1) ? NORM_IGNORECASE : 0, p, find_str_len, str, find_str_len) == 2) {
			SendMessage(wkWnd, EM_SETSEL, lstrlen(buf) - str_len, lstrlen(buf) - str_len + find_str_len);
			ret = TRUE;
			break;
		}
	}
	LocalFree(buf);
	return ret;
}

/*
 * find_item - アイテムから検索
 */
static int find_item(const HWND hWnd, const HTREEITEM hitem, const HTREEITEM end_item, const TCHAR *str, const int icase)
{
	HWND hTreeView = GetDlgItem(hWnd, ID_TREE);
	HTREEITEM citem = hitem;
	TV_ITEM tvit;
	DATA_INFO *di;
	BYTE *mem;
	TCHAR *p;
	int find_str_len = lstrlen(str);
	int str_len;
	int ret;

	while (citem != NULL) {
		// 子アイテムを検索
		if ((ret = find_item(hWnd, TreeView_GetChild(hTreeView, citem), end_item, str, icase)) != 0) {
			return ret;
		}
		// アイテム情報取得
		tvit.mask = TVIF_PARAM;
		tvit.hItem = citem;
		tvit.lParam = 0;
		TreeView_GetItem(hTreeView, &tvit);
		if ((di = (DATA_INFO *)tvit.lParam) != NULL && di->type == TYPE_ITEM &&
			(di = (DATA_INFO *)SendMessage(hWnd, WM_ITEM_GET_FORMAT_TO_ITEM, (WPARAM)TEXT("TEXT"), (LPARAM)di)) != NULL &&
			di->data != NULL && (mem = GlobalLock(di->data)) != NULL) {
			// テキスト検索
			p = mem;
			str_len = lstrlen(p);
			ret = 0;
			for (; *p != TEXT('\0') && find_str_len <= str_len; p++, str_len--) {
				if (CompareString(MAKELCID(MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), SORT_DEFAULT),
					(icase == 1) ? NORM_IGNORECASE : 0, p, find_str_len, str, find_str_len) == 2) {
					ret = 1;
					break;
				}
			}
			GlobalUnlock(di->data);
			if (ret == 1) {
				// 見つかったアイテムを選択
				TreeView_SelectItem(hTreeView, citem);
				if (find_text(hWnd, str, icase, FALSE) == FALSE) {
					find_text(hWnd, str, icase, TRUE);
				}
				return 1;
			}
		}
		if (end_item == citem) {
			// 1周した場合は検索終了
			return -1;
		}
		citem = TreeView_GetNextSibling(hTreeView, citem);
	}
	return 0;
}

/*
 * find_tree - ツリーから検索
 */
static void find_tree(const HWND hWnd, const TCHAR *str, const int icase)
{
	HWND hTreeView = GetDlgItem(hWnd, ID_TREE);
	HTREEITEM sel_item;
	HTREEITEM citem;
	HTREEITEM pitem;
	HCURSOR old_cursor;
	int ret = 0;

	// 現在表示中のテキストから検索
	if (find_text(hWnd, str, icase, FALSE) == TRUE) {
		return;
	}

	// 選択アイテム取得
	if ((sel_item = TreeView_GetSelection(hTreeView)) == NULL) {
		return;
	}
	old_cursor = SetCursor(LoadCursor(NULL, IDC_WAIT));
	// 子アイテムを検索
	if ((citem = TreeView_GetChild(hTreeView, sel_item)) != NULL) {
		ret = find_item(hWnd, citem, sel_item, str, icase);
	}
	// 次のアイテムを検索
	if (ret == 0 && (citem = TreeView_GetNextSibling(hTreeView, sel_item)) != NULL) {
		ret = find_item(hWnd, citem, sel_item, str, icase);
	}
	// 親を辿って検索
	pitem = sel_item;
	while (ret == 0 && (pitem = TreeView_GetParent(hTreeView, pitem)) != NULL) {
		if ((citem = TreeView_GetNextSibling(hTreeView, pitem)) != NULL) {
			ret = find_item(hWnd, citem, sel_item, str, icase);
		}
	}
	// ルートから検索
	if (ret == 0) {
		ret = find_item(hWnd, TreeView_GetRoot(hTreeView), sel_item, str, icase);
	}
	SetCursor(old_cursor);

	SetForegroundWindow(hWnd);
	if (ret != 1) {
		TCHAR msg[BUF_SIZE * 2];

		// 検索アイテムが見つからない場合はメッセージボックスを出す
		wsprintf(msg, TEXT("\"%s\" が見つかりません。"), str);
		MessageBox(hWnd, msg, TEXT("検索"), MB_ICONEXCLAMATION);
	}
}

/*
 * find_str_proc - 検索文字列入力
 */
BOOL CALLBACK find_str_proc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch (uMsg) {
	case WM_INITDIALOG:
		SendDlgItemMessage(hDlg, IDC_EDIT_FIND, WM_SETTEXT, 0, (LPARAM)find_str);
		CheckDlgButton(hDlg, IDC_CHECK_CASE, !op_ignore_case);
		break;

	case WM_CLOSE:
		EndDialog(hDlg, FALSE);
		break;

	case WM_COMMAND:
		switch (LOWORD(wParam)) {
		case IDOK:
			SendDlgItemMessage(hDlg, IDC_EDIT_FIND, WM_GETTEXT, BUF_SIZE - 1, (LPARAM)find_str);
			op_ignore_case = !IsDlgButtonChecked(hDlg, IDC_CHECK_CASE);

			EndDialog(hDlg, TRUE);
			break;

		case IDCANCEL:
			EndDialog(hDlg, FALSE);
			break;
		}
		break;

	default:
		return FALSE;
	}
	return TRUE;
}

/*
 * tool_find - 検索
 */
__declspec(dllexport) int CALLBACK tool_find(const HWND hWnd, TOOL_EXEC_INFO *tei, TOOL_DATA_INFO *tdi)
{
	HWND hViewerWnd;

	if ((hViewerWnd = (HWND)SendMessage(hWnd, WM_VIEWER_GET_HWND, 0, 0)) == NULL) {
		SendMessage(hWnd, WM_VIEWER_SHOW, 0, 0);
		if ((hViewerWnd = (HWND)SendMessage(hWnd, WM_VIEWER_GET_HWND, 0, 0)) == NULL) {
			return TOOL_SUCCEED;
		}
	}
	SetForegroundWindow(hViewerWnd);
	if (DialogBoxParam(hInst, MAKEINTRESOURCE(IDD_DIALOG_FIND), hViewerWnd, find_str_proc, 0) == FALSE) {
		return TOOL_SUCCEED;
	}
	if (*find_str == TEXT('\0')) {
		return TOOL_SUCCEED;
	}
	find_tree(hViewerWnd, find_str, op_ignore_case);
	return TOOL_SUCCEED;
}

/*
 * tool_find_property - プロパティ表示
 */
__declspec(dllexport) BOOL CALLBACK tool_find_property(const HWND hWnd, TOOL_EXEC_INFO *tei)
{
	return FALSE;
}

/*
 * tool_find_next - 次を検索
 */
__declspec(dllexport) int CALLBACK tool_find_next(const HWND hWnd, TOOL_EXEC_INFO *tei, TOOL_DATA_INFO *tdi)
{
	HWND hViewerWnd;

	if ((hViewerWnd = (HWND)SendMessage(hWnd, WM_VIEWER_GET_HWND, 0, 0)) == NULL) {
		SendMessage(hWnd, WM_VIEWER_SHOW, 0, 0);
		if ((hViewerWnd = (HWND)SendMessage(hWnd, WM_VIEWER_GET_HWND, 0, 0)) == NULL) {
			return TOOL_SUCCEED;
		}
	}
	if (*find_str == TEXT('\0')) {
		SetForegroundWindow(hViewerWnd);
		if (DialogBoxParam(hInst, MAKEINTRESOURCE(IDD_DIALOG_FIND), hViewerWnd, find_str_proc, 0) == FALSE) {
			return TOOL_SUCCEED;
		}
		if (*find_str == TEXT('\0')) {
			return TOOL_SUCCEED;
		}
	}
	find_tree(hViewerWnd, find_str, op_ignore_case);
	return TOOL_SUCCEED;
}

/*
 * tool_find_next_property - プロパティ表示
 */
__declspec(dllexport) BOOL CALLBACK tool_find_next_property(const HWND hWnd, TOOL_EXEC_INFO *tei)
{
	return FALSE;
}
/* End of source */
