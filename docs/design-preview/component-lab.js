(() => {
  const root = document.documentElement;
  const toast = document.querySelector('#toast');
  let toastTimer;
  function showToast(message) {
    toast.textContent = message;
    toast.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { toast.hidden = true; }, 3200);
  }

  document.querySelectorAll('[data-theme-choice]').forEach(button => {
    button.addEventListener('click', () => {
      root.dataset.theme = button.dataset.themeChoice;
      document.querySelectorAll('[data-theme-choice]').forEach(choice => {
        const selected = choice === button;
        choice.classList.toggle('is-selected', selected);
        choice.setAttribute('aria-pressed', String(selected));
      });
    });
  });
  document.querySelector('#densitySelect').addEventListener('change', event => {
    root.dataset.density = event.target.value;
  });

  document.addEventListener('click', event => {
    const button = event.target.closest('[data-toast]');
    if (button) showToast(button.dataset.toast);
  });
  document.querySelectorAll('[data-copy]').forEach(button => {
    button.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(button.dataset.copy);
        showToast(`Đã sao chép ${button.dataset.copy}`);
      } catch {
        showToast(`Mã màu: ${button.dataset.copy}`);
      }
    });
  });

  const pinButton = document.querySelector('#pinButton');
  pinButton.addEventListener('click', () => {
    const pinned = pinButton.getAttribute('aria-pressed') !== 'true';
    pinButton.setAttribute('aria-pressed', String(pinned));
    pinButton.textContent = pinned ? '♣' : '♧';
    pinButton.setAttribute('aria-label', pinned ? 'Bỏ ghim mục' : 'Ghim mục');
    showToast(pinned ? 'Đã ghim mục mẫu' : 'Đã bỏ ghim mục mẫu');
  });

  const loadingOverlay = document.querySelector('#loadingOverlay');
  function simulateLoading(button, overlay = false, completionMessage = 'Đã hoàn tất thao tác mẫu') {
    const oldText = button.textContent;
    button.disabled = true;
    button.textContent = 'Đang xử lý…';
    if (overlay) loadingOverlay.hidden = false;
    setTimeout(() => {
      button.disabled = false;
      button.textContent = oldText;
      loadingOverlay.hidden = true;
      if (completionMessage) showToast(completionMessage);
    }, 1500);
  }
  document.querySelector('#loadingButton').addEventListener('click', event => simulateLoading(event.currentTarget));
  document.querySelector('#progressButton').addEventListener('click', event => simulateLoading(event.currentTarget, true));

  const form = document.querySelector('#captureForm');
  const noteInput = document.querySelector('#noteInput');
  const urlInput = document.querySelector('#urlInput');
  const urlHelp = document.querySelector('#urlHelp');
  const photoButton = document.querySelector('#photoButton');
  const photoHelp = photoButton.querySelector('small');
  const formError = document.querySelector('#formError');
  const charCount = document.querySelector('#charCount');
  const draftState = document.querySelector('#draftState');
  const formSubmit = document.querySelector('#formSubmit');
  let mode = 'note';
  let photoChosen = false;
  let formBusy = false;
  let draftTimer;

  function setMode(nextMode) {
    mode = nextMode;
    document.querySelectorAll('[data-mode]').forEach(button => {
      const selected = button.dataset.mode === mode;
      button.classList.toggle('selected', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    document.querySelector('#urlField').hidden = mode !== 'link';
    document.querySelector('#photoField').hidden = mode !== 'photo';
    document.querySelector('#noteLabel').innerHTML = mode === 'note'
      ? 'Điều bạn muốn giữ <span class="required">*</span>'
      : 'Ghi chú đi kèm <span class="required">tùy chọn</span>';
    formSubmit.textContent = mode === 'note' ? 'Lưu ghi chú' : mode === 'link' ? 'Lưu liên kết' : 'Lưu ảnh';
    formError.textContent = '';
    noteInput.removeAttribute('aria-invalid');
    urlInput.removeAttribute('aria-invalid');
    urlHelp.textContent = 'Chỉ hỗ trợ liên kết http và https.';
    urlHelp.classList.remove('error-text');
    photoHelp.textContent = 'Prototype không truy cập ảnh trên máy';
    photoHelp.classList.remove('error-text');
  }
  document.querySelectorAll('[data-mode]').forEach(button => button.addEventListener('click', () => setMode(button.dataset.mode)));
  function updateDraft() {
    charCount.textContent = `${noteInput.value.length} / 500`;
    formError.textContent = '';
    noteInput.removeAttribute('aria-invalid');
    urlInput.removeAttribute('aria-invalid');
    urlHelp.textContent = 'Chỉ hỗ trợ liên kết http và https.';
    urlHelp.classList.remove('error-text');
    draftState.textContent = 'Đang giữ bản nháp mẫu…';
    clearTimeout(draftTimer);
    draftTimer = setTimeout(() => { draftState.textContent = 'Bản nháp trong trang · mẫu'; }, 450);
  }
  noteInput.addEventListener('input', updateDraft);
  urlInput.addEventListener('input', updateDraft);
  photoButton.addEventListener('click', event => {
    photoChosen = true;
    event.currentTarget.querySelector('span').textContent = 'Đã chọn ảnh minh họa';
    photoHelp.textContent = 'Ảnh mẫu đã sẵn sàng để lưu';
    photoHelp.classList.remove('error-text');
    showToast('Đã chọn ảnh mẫu; trang không truy cập thư viện ảnh');
  });
  form.addEventListener('submit', event => {
    event.preventDefault();
    if (formBusy) return;
    const note = noteInput.value.trim();
    const url = urlInput.value.trim();
    if (mode === 'note' && !note) {
      formError.textContent = 'Hãy nhập nội dung trước khi lưu.';
      noteInput.setAttribute('aria-invalid', 'true');
      noteInput.focus();
      return;
    }
    if (mode === 'link') {
      let valid = false;
      try { const parsed = new URL(url); valid = ['http:', 'https:'].includes(parsed.protocol) && Boolean(parsed.hostname); } catch { /* invalid URL */ }
      if (!valid) {
        urlHelp.textContent = 'Nhập liên kết http hoặc https hợp lệ.';
        urlHelp.classList.add('error-text');
        urlInput.setAttribute('aria-invalid', 'true');
        urlInput.focus();
        return;
      }
    }
    if (mode === 'photo' && !photoChosen) {
      photoHelp.textContent = 'Hãy chọn ảnh minh họa trước khi lưu.';
      photoHelp.classList.add('error-text');
      photoButton.focus();
      return;
    }
    formBusy = true;
    simulateLoading(formSubmit, false, '');
    setTimeout(() => {
      formBusy = false;
      showToast('Đã lưu nội dung mẫu trong prototype');
      form.reset();
    }, 1510);
  });
  form.addEventListener('reset', () => {
    setTimeout(() => {
      photoChosen = false;
      document.querySelector('#photoButton span').textContent = 'Chọn ảnh minh họa';
      setMode('note');
      updateDraft();
    }, 0);
  });

  const filters = [...document.querySelectorAll('[data-filter]')];
  const cards = [...document.querySelectorAll('#cardGrid .content-card')];
  filters.forEach(button => button.addEventListener('click', () => {
    const filter = button.dataset.filter;
    filters.forEach(choice => {
      const selected = choice === button;
      choice.classList.toggle('active', selected);
      choice.setAttribute('aria-pressed', String(selected));
    });
    let count = 0;
    cards.forEach(card => {
      const visible = filter === 'all' || (filter === 'pinned' ? card.dataset.pinned === 'true' : card.dataset.kind === filter);
      card.hidden = !visible;
      if (visible) count++;
    });
    document.querySelector('#filterResult').textContent = `${count} mục`;
  }));

  const screens = [...document.querySelectorAll('[data-screen]')];
  function setScreen(name) {
    screens.forEach(button => {
      const selected = button.dataset.screen === name;
      button.classList.toggle('active', selected);
      button.classList.toggle('selected', selected);
      button.setAttribute('aria-current', selected ? 'page' : 'false');
    });
    document.querySelectorAll('[data-device-page]').forEach(page => page.classList.toggle('active', page.dataset.devicePage === name));
  }
  screens.forEach(button => button.addEventListener('click', () => setScreen(button.dataset.screen)));
  document.querySelectorAll('[data-device-filter]').forEach(button => button.addEventListener('click', () => {
    const filter = button.dataset.deviceFilter;
    document.querySelectorAll('[data-device-filter]').forEach(choice => choice.classList.toggle('active', choice === button));
    document.querySelectorAll('[data-device-kind]').forEach(card => { card.hidden = filter !== 'all' && card.dataset.deviceKind !== filter; });
  }));
  const normalize = text => text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/đ/g, 'd');
  document.querySelector('#deviceSearch').addEventListener('input', event => {
    const query = normalize(event.target.value.trim());
    let count = 0;
    document.querySelectorAll('[data-search-text]').forEach(result => {
      const matches = normalize(result.dataset.searchText).includes(query);
      result.hidden = !matches;
      if (matches) count++;
    });
    document.querySelector('#deviceSearchHeading').textContent = query ? 'Kết quả tìm kiếm' : 'Mới lưu';
    document.querySelector('#deviceSearchCount').textContent = `${count} mục`;
  });

  const dialog = document.querySelector('#confirmDialog');
  document.querySelector('#openDialog').addEventListener('click', () => { dialog.returnValue = ''; dialog.showModal(); });
  dialog.addEventListener('close', () => {
    if (dialog.returnValue === 'confirm') showToast('Đã chọn chuyển mục mẫu vào Thùng rác');
  });
  const sheet = document.querySelector('#captureSheet');
  const showSheet = () => { sheet.returnValue = ''; sheet.showModal(); };
  document.querySelector('#openSheet').addEventListener('click', showSheet);
  document.querySelector('#deviceSave').addEventListener('click', showSheet);
  sheet.querySelector('.sheet-save').addEventListener('click', event => {
    if (!document.querySelector('#sheetText').value.trim()) {
      event.preventDefault();
      document.querySelector('#sheetText').focus();
      showToast('Hãy nhập nội dung trước khi lưu');
    }
  });
  sheet.addEventListener('close', () => {
    if (sheet.returnValue === 'save') {
      const content = document.querySelector('#sheetText').value.trim();
      showToast('Đã lưu ghi chú mẫu trong prototype');
      if (content) document.querySelector('#sheetText').value = '';
    }
  });

  const deviceGrid = document.querySelector('.device-card-grid');
  const empty = document.createElement('div');
  empty.className = 'device-empty';
  empty.innerHTML = '<span>▧</span><strong>Chỗ cho những điều muốn giữ</strong><small>Chọn Lưu nhanh để bắt đầu.</small>';
  empty.hidden = true;
  deviceGrid.after(empty);
  document.querySelector('#emptyButton').addEventListener('click', () => {
    const showing = empty.hidden;
    empty.hidden = !showing;
    deviceGrid.hidden = showing;
    showToast(showing ? 'Đang xem empty state trong Thư viện' : 'Đã trở lại danh sách mẫu');
    setScreen('library');
  });
  document.querySelector('#errorButton').addEventListener('click', () => showToast('Chưa lưu được. Bản nháp vẫn còn, hãy thử lại.'));

  const sideLinks = [...document.querySelectorAll('.side-nav a')];
  sideLinks.forEach(link => link.addEventListener('click', () => {
    sideLinks.forEach(item => item.classList.toggle('active', item === link));
  }));
})();
