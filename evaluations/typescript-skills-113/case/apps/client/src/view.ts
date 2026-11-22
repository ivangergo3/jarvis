export class View {
  selected = '';
  message = '';

  async select(id: string, read: (id: string) => Promise<string>) {
    this.selected = id;
    this.message = await read(id);
  }
}
