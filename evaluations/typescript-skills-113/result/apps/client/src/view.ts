export class View {
  selected = '';
  message = '';
  private generation = 0;

  async select(id: string, read: (id: string) => Promise<string>) {
    const generation = ++this.generation;
    if (this.selected !== id) this.message = '';
    this.selected = id;
    const message = await read(id);
    if (generation === this.generation) this.message = message;
  }
}
