export type ContentUnit = 'grams' | 'ml' | 'l';
export type Packaging = 'bottle' | 'can' | 'box' | 'bag' | 'jar' | 'package' | 'other';

export interface Item {
  id: string;
  inventoryTag: string;
  name: string;
  bestBefore: string;
  contentAmount: number;
  contentUnit: ContentUnit;
  packaging: Packaging;
  pictureKey: string | null;
  comment?: string;
  createdAt: string;
  updatedAt: string;
}

export interface JsonApiItemAttributes {
  name: string;
  best_before: string;
  content_amount: number;
  content_unit: ContentUnit;
  packaging: Packaging;
  picture_key: string | null;
  comment?: string;
  inventory_tag: string;
  created_at: string;
  updated_at: string;
}

export interface JsonApiItemResource {
  type: 'items';
  id: string;
  attributes: JsonApiItemAttributes;
}

export interface JsonApiListResponse {
  data: JsonApiItemResource[];
}

export type ItemSortBy = 'name' | 'best_before' | 'created_at' | 'updated_at';
export type SortOrder = 'asc' | 'desc';

export interface CreateItemInput {
  name: string;
  bestBefore: string;
  contentAmount: number;
  contentUnit: ContentUnit;
  packaging: Packaging;
  pictureKey: string | null;
  comment?: string;
}
