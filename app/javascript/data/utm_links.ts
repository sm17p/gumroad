export type UtmLinkDestinationOption = {
  id: string;
  label: string;
  url: string;
};

export type UtmLink = {
  id?: string;
  destination_option?: UtmLinkDestinationOption;
  title: string;
  short_url: string;
  utm_url: string;
  created_at: string;
  source: string;
  medium: string;
  campaign: string;
  term: string | null;
  content: string | null;
  clicks: number;
  sales_count: number | null;
  revenue_cents: number | null;
  conversion_rate: number | null;
};

export type SavedUtmLink = UtmLink & {
  id: string;
};

export type UtmLinkStats = {
  sales_count: number | null;
  revenue_cents: number | null;
  conversion_rate: number | null;
};

export type UtmLinksStats = Record<string, UtmLinkStats>;

export type UtmLinkFormStaticMetaData = {
  destination_options: UtmLinkDestinationOption[];
  utm_fields_values: {
    campaigns: string[];
    mediums: string[];
    sources: string[];
    terms: string[];
    contents: string[];
  };
  short_url_prefix: string;
  short_url_protocol: string;
};

export type UtmLinkFormData = {
  title: string;
  destination_option: UtmLinkDestinationOption | null;
  target_resource_type: string | null;
  target_resource_id: string | null;
  permalink: string;
  utm_source: string | null;
  utm_medium: string | null;
  utm_campaign: string | null;
  utm_term: string | null;
  utm_content: string | null;
};

export type UtmLinkNewPageProps = {
  context: UtmLinkFormStaticMetaData;
  utm_link: UtmLinkFormData;
};

export type UtmLinkEditPageProps = {
  context: UtmLinkFormStaticMetaData;
  utm_link: UtmLinkFormData & { id: string };
};

export type SortKey =
  | "link"
  | "date"
  | "source"
  | "medium"
  | "campaign"
  | "clicks"
  | "sales_count"
  | "revenue_cents"
  | "conversion_rate";
