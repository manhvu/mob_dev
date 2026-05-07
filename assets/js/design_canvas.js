// Design Canvas - Drag and Drop functionality for Dala UI Designer

const DesignCanvas = {
  mounted() {
    this.el.addEventListener('dragover', this.handleDragOver.bind(this));
    this.el.addEventListener('drop', this.handleDrop.bind(this));
    this.el.addEventListener('dragleave', this.handleDragLeave.bind(this));
    this.el.addEventListener('dragenter', this.handleDragEnter.bind(this));
    
    // Make nodes draggable
    this.makeNodesDraggable();
    
    // Setup resize handles
    this.setupResizeHandles();
    
    // Hide drop zone hint after first interaction
    this.hideDropZoneHint();
  },

  handleDragOver(e) {
    e.preventDefault();
    e.stopPropagation();
    
    const rect = this.el.getBoundingClientRect();
    const scale = parseFloat(this.el.dataset.zoom) / 100;
    const x = (e.clientX - rect.left) / scale;
    const y = (e.clientY - rect.top) / scale;
    
    // Show drop zone hint
    this.showDropZoneHint(x, y);
    
    // Update ghost position
    this.updateGhostPosition(e.clientX, e.clientY);
  },

  handleDragEnter(e) {
    e.preventDefault();
    e.stopPropagation();
    this.el.classList.add('drag-over');
  },

  handleDragLeave(e) {
    e.preventDefault();
    e.stopPropagation();
    this.el.classList.remove('drag-over');
    this.hideDropZoneHint();
  },

  handleDrop(e) {
    e.preventDefault();
    e.stopPropagation();
    this.el.classList.remove('drag-over');
    this.hideDropZoneHint();
    
    const rect = this.el.getBoundingClientRect();
    const scale = parseFloat(this.el.dataset.zoom) / 100;
    const x = (e.clientX - rect.left) / scale;
    const y = (e.clientY - rect.top) / scale;
    
    const type = e.dataTransfer.getData('text/plain');
    
    if (type) {
      this.pushEvent('drop', {
        x: Math.round(x),
        y: Math.round(y),
        type: type
      });
    }
  },

  showDropZoneHint(x, y) {
    const hint = document.getElementById('drop-zone-hint');
    if (hint) {
      hint.style.display = 'block';
      hint.style.left = x + 'px';
      hint.style.top = y + 'px';
    }
  },

  hideDropZoneHint() {
    const hint = document.getElementById('drop-zone-hint');
    if (hint) {
      hint.style.display = 'none';
    }
  },

  updateGhostPosition(x, y) {
    const ghost = document.getElementById('drag-ghost');
    if (ghost) {
      ghost.style.left = (x + 10) + 'px';
      ghost.style.top = (y + 10) + 'px';
    }
  },

  makeNodesDraggable() {
    const canvas = this.el;
    let draggedNode = null;
    let offsetX = 0;
    let offsetY = 0;
    let startX = 0;
    let startY = 0;

    canvas.addEventListener('mousedown', (e) => {
      const nodeEl = e.target.closest('.canvas-node');
      if (nodeEl && !e.target.closest('.node-resize-handle')) {
        e.preventDefault();
        draggedNode = nodeEl;
        
        const rect = nodeEl.getBoundingClientRect();
        const canvasRect = canvas.getBoundingClientRect();
        
        offsetX = e.clientX - rect.left;
        offsetY = e.clientY - rect.top;
        startX = parseInt(nodeEl.style.left) || 0;
        startY = parseInt(nodeEl.style.top) || 0;
        
        nodeEl.classList.add('dragging');
        
        const onMouseMove = (moveEvent) => {
          if (!draggedNode) return;
          
          const scale = parseFloat(canvas.dataset.zoom) / 100;
          const snap = canvas.dataset.snapToGrid === 'true';
          const gridSize = parseInt(canvas.dataset.gridSize) || 20;
          
          let newX = startX + (moveEvent.clientX - e.clientX) / scale;
          let newY = startY + (moveEvent.clientY - e.clientY) / scale;
          
          if (snap) {
            newX = Math.round(newX / gridSize) * gridSize;
            newY = Math.round(newY / gridSize) * gridSize;
          }
          
          draggedNode.style.left = newX + 'px';
          draggedNode.style.top = newY + 'px';
        };
        
        const onMouseUp = () => {
          if (draggedNode) {
            draggedNode.classList.remove('dragging');
            
            const nodeId = draggedNode.dataset.id;
            const newX = parseInt(draggedNode.style.left) || 0;
            const newY = parseInt(draggedNode.style.top) || 0;
            
            this.pushEvent('move_node', {
              id: nodeId,
              x: newX,
              y: newY
            });
          }
          
          draggedNode = null;
          document.removeEventListener('mousemove', onMouseMove);
          document.removeEventListener('mouseup', onMouseUp);
        };
        
        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
      }
    });
  },

  setupResizeHandles() {
    const canvas = this.el;
    
    canvas.addEventListener('mousedown', (e) => {
      if (e.target.classList.contains('node-resize-handle')) {
        e.preventDefault();
        const nodeEl = e.target.closest('.canvas-node');
        // Implement resize logic here
      }
    });
  }
};

// Initialize drag for component items
document.addEventListener('DOMContentLoaded', () => {
  const componentItems = document.querySelectorAll('.component-item[draggable="true"]');
  
  componentItems.forEach(item => {
    item.addEventListener('dragstart', (e) => {
      const type = item.dataset.type;
      e.dataTransfer.setData('text/plain', type);
      e.dataTransfer.effectAllowed = 'copy';
      
      // Create ghost image
      const ghost = document.getElementById('drag-ghost');
      if (ghost) {
        ghost.style.display = 'block';
        ghost.textContent = item.querySelector('.component-icon').textContent;
      }
    });
    
    item.addEventListener('dragend', () => {
      const ghost = document.getElementById('drag-ghost');
      if (ghost) {
        ghost.style.display = 'none';
      }
    });
  });
});

export default DesignCanvas;
